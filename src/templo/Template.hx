package templo;

import templo.Ast;
import templo.Token;

/**
	The templo Template class provides advanced templating support.
	
	Templo directives start with two double-dots: `::directive`. The supported
	directives are:
		
		- `::raw`
		- `::if`, `::elseif` and `::else`
		- `::foreach`
		- `::set`
		- `::fill`
		- `::cond` (within node definition)
		- `::repeat`` (within node definition)
		- `::switch` and `::case`
	
	The following directives are currently unsupported due to varying reasons:
		
		- `::use`
		- `::attr`
**/
class Template {

	static var partMap:Map<String, Part> = new Map();
	
	var part:Part;
	
	/**
		Creates a new Template by parsing `input`.
		
		If `sourceName` is provided, error messages will contain its value. It
		is also recorded in a global lookup and can be used as argument to
		`::use`.
		
		The parsing process is expensive, but it only has to be done once for
		each input source. Template maintains no state other than the parsed
		template information, so the intended usage is to create a Template
		once and then invoke its `execute` method multiple times.
		
		If `input` is null, the result is unspecified.
	**/
	public function new(input:haxe.io.Input, ?sourceName = null) {
		var parser = new templo.Parser(input, sourceName);
		part = templo.Converter.toAst(parser.parse());
		if (sourceName != null) partMap.set(sourceName, part);
	}
	
	/**
		Convenience function for creating a new Template from a String.
	**/
	static public function fromString(s:String, ?sourceName = null) {
		return new Template(new haxe.io.StringInput(s), sourceName);
	}
	
	#if sys
	/**
		Convenience function for creating a new Template from a file.
	**/
	static public function fromFile(path:String) {
		var p = new haxe.io.Path(path);
		return new Template(sys.io.File.read(path), p.file + "." + p.ext);
	}
	#end
	
	/**
		Executes `this` Template with the provided `data` as context.
		
		Each invocation of `execute` has its own context.
	**/
	public function execute(data:{}) {
		var ctx = new Context();
		ctx.push();
		ctx.bind("null", null);
		ctx.bind("true", true);
		ctx.bind("false", false);
		if (data != null) Lambda.iter(Reflect.fields(data), function(s) ctx.bind(s, Reflect.field(data, s)));
		processPart(ctx, part);
		ctx.pop();
		return ctx.getContent();
	}
	
	function processPart(ctx:Context, e:Part) {
		switch(e) {
			case PBlock(pl): pl.map(processPart.bind(ctx));
			case PSet(s, e): ctx.bind(s, eval(ctx, e));
			case PData(s) | PComment(s): ctx.append(s);
			case PMacroCall(s, cl): callMacro(ctx, s, cl);
			case PIf(eif, pthen, pelse):
				if(eval(ctx, eif)) processPart(ctx, pthen);
				else if (pelse != null) processPart(ctx, pelse);
			case PForeach(s, it, p):
				var v = getIterator(eval(ctx, it));
				iterate(ctx, s, v, p);
			case PValue(e): ctx.append(display(eval(ctx, e)));
			case PRaw(e): ctx.append(eval(ctx, e));
			case PNode(node) if (node.cond != null && eval(ctx, node.cond) == false):
			case PNode(node) if (node.repeat != null):
				var v = getIterator(eval(ctx, node.repeat.t));
				var r = node.repeat;
				node.repeat = null;
				iterate(ctx, r.name, v, e);
				node.repeat = r;
			case PNode(node):
				ctx.newline();
				ctx.append('<${node.node}');
				for (attr in node.attributes) {
					ctx.append(' ${attr.name}="');
					processPart(ctx, attr.t);
					ctx.append('"');
				}
				ctx.append(">");
				ctx.newline();
				ctx.increaseIndent();
				if (node.content != null) processPart(ctx, node.content);
				ctx.decreaseIndent();
				ctx.newline();
				ctx.append('</${node.node}>');
				ctx.newline();
			case PFill(s, body):
				ctx.pushBuffer();
				processPart(ctx, body);
				ctx.bind(s, ctx.popBuffer().toString());
			case PSwitch(e1, cases, def):
				var v = eval(ctx, e1);
				var i = Type.enumIndex(v);
				if (i >= cases.length)
					processPart(ctx, def);
				else {
					ctx.push();
					ctx.bind("args", Type.enumParameters(v));
					processPart(ctx, cases[i]);
					ctx.pop();
				}
		}
	}
	
	function callMacro(ctx:Context, s:String, cl:Array<Part>) {
		ctx.push();
		var m = Converter.macros.get(s); // TODO: decouple
		if (m == null) throw 'Unknown macro: $s';
		for (i in 0...cl.length) {
			var arg = m.args[i];
			switch(cl[i]) {
				case PValue(e):
					ctx.bind(arg.name, eval(ctx, e));
				case t:
					throw 'Unexpected macro arg: $t';
			}
		}
		processPart(ctx, m.part);
		ctx.pop();
	}
	
	function display(v:Dynamic) {
		return v == null ? "" : StringTools.htmlEscape(Std.string(v));
	}
	
	function getIterator(v:Dynamic):Iterator<Dynamic> {
		try {
			var x : Dynamic = v.iterator();
			if( x.hasNext == null ) throw null;
			v = x;
		} catch( e : Dynamic ) try {
			if( v.hasNext == null ) throw null;
		} catch( e : Dynamic ) {
			throw "Cannot iter on " + v;
		}
		return v;		
	}
	
	function iterate<T>(ctx:Context, s:String, v:Iterator<T>, part:Part) {
		var repeat = {
			index: -1,
			number: 0,
			odd: true,
			even: false,
			first: true,
			last: false,
			size: 0
		};
		ctx.push();
		var r = ctx.lookup("repeat", null);
		if (r == null) {
			r = {};
			ctx.bind("repeat", r);
		}
		Reflect.setField(r, s, repeat);
		for ( i in v ) {
			repeat.index++;
			repeat.number++;
			repeat.even = repeat.index & 1 == 0;
			repeat.odd = !repeat.even;
			repeat.last = !v.hasNext();
			ctx.push();
			ctx.bind(s, i);
			processPart(ctx, part);
			ctx.pop();
			repeat.first = false;
		}
		ctx.pop();
	}
	
	function eval(ctx:Context, e:Expr):Dynamic {
		return switch(e.expr) {
			case VConst(c):
				switch(c) {
					case CInt(i): i;
					case CString(s): s;
					case CFloat(s): Std.parseFloat(s);
				}
			case VIdent(s):
				ctx.lookup(s, e.pos);
			case VVar(s):
				null;
			case VIf(econd, ethen, null):
				if (eval(ctx, econd)) eval(ctx, ethen) else null;
			case VIf(econd, ethen, eelse):
				if (eval(ctx, econd)) eval(ctx, ethen) else eval(ctx, eelse);		
			case VField(e1, s):
				Reflect.field(eval(ctx,e1), s);
			case VParent(e1):
				eval(ctx, e1);
			case VUnop(op, false, e1):
				var e1:Dynamic = eval(ctx, e1);
				switch(op) {
					case Not: !e1;
					case Neg: -e1;
					case Increment: ++e1;
					case Decrement: --e1;
				}
			case VUnop(_, true, _):
				throw "postfix unops are not supported";
			case VLiteral(e1):
				eval(ctx, e1); // ???
			case VBinop(op, e1, e2):
				var e1:Dynamic = eval(ctx, e1);
				var e2:Dynamic = eval(ctx, e2);
				switch(op) {
					case OpAdd: e1 + e2;
					case OpMult: e1 * e2;
					case OpDiv: e1 / e2;
					case OpSub: e1 - e2;
					case OpEq: e1 == e2;
					case OpNotEq: e1 != e2;
					case OpGt: e1 > e2;
					case OpGte: e1 >= e2;
					case OpLt: e1 < e2;
					case OpLte: e1 <= e2;
					case OpAnd: e1 & e2;
					case OpOr: e1 | e2;
					case OpXor: e1 ^ e2;
					case OpBoolAnd: e1 && e2;
					case OpBoolOr: e1 || e2;
					case OpShl: e1 << e2;
					case OpShr: e1 >> e2;
					case OpUShr: e1 >>> e2;
					case OpMod: e1 % e1;
					case OpCompare: throw "???";
					case OpAssign:
						throw "assigning is not supported";	
				}
			case VObject(fl):
				var r = { };
				for (f in fl) {
					Reflect.setField(r, f.name, eval(ctx, f.expr));
				}
				r;
			case VBool(e1):
				throw "???";
			case VArray(e1, e2):
				untyped eval(ctx, e1)[eval(ctx, e2)];
			case VArrayDecl(el):
				el.map(eval.bind(ctx));
			case VCall(e1, el):
				var e1 = eval(ctx, e1);
				Reflect.callMethod(ctx, e1, el.map(eval.bind(ctx)));
		}
	}
}

typedef CtxStack = haxe.ds.GenericStack<haxe.ds.StringMap<Dynamic>>;

class Context {
	
	var tabs(default, null):String;
	var stack:CtxStack;
	var buffer:StringBuf;
	var hasNewline:Bool;
	
	var bufferStack:haxe.ds.GenericStack<StringBuf>;
	
	public function new() {
		stack = new CtxStack();
		tabs = "";
		buffer = new StringBuf();
		bufferStack = new haxe.ds.GenericStack<StringBuf>();
		hasNewline = false;
	}
	
	public inline function push() {
		stack.add(new haxe.ds.StringMap());
	}
	
	public inline function pop() {
		return stack.pop();
	}
	
	public inline function pushBuffer() {
		bufferStack.add(buffer);
		buffer = new StringBuf();
	}
	
	public inline function popBuffer() {
		var b = buffer;
		buffer = bufferStack.pop();
		return b;
	}
	
	public function bind<T>(s:String, v:T) {
		stack.first().set(s, v);
	}
	
	public function lookup(s:String, pos:hxparse.Lexer.Pos) {
		for (st in stack) {
			if (st.exists(s)) return st.get(s);
		}
		//trace(formatPos(pos) + ": Warning: Unknown identifier " +s);
		return null;
	}
	
	public function append(s:String) {
		if (hasNewline) {
			buffer.add(tabs);
			hasNewline = false;
		}
		buffer.add(s);
	}
	
	public inline function newline() {
		if (!hasNewline) {
			buffer.add("\n");
			hasNewline = true;
		}
	}
	
	public function increaseIndent() {
		tabs += "\t";
	}
	
	public function decreaseIndent() {
		tabs = tabs.substr(1);
	}
	
	public function getContent() {
		return buffer.toString();
	}
	
	function formatPos(pos:hxparse.Lexer.Pos) {
		return '${pos.psource}:${pos.pline}';
	}
}