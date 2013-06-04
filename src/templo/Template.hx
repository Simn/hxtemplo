package templo;

import templo.Ast;
import templo.Token;

class Template {

	var part:Part;
	
	public function new(input:haxe.io.Input, ?sourceName = null) {
		var parser = new templo.Parser(input, sourceName);
		part = templo.Converter.toAst(parser.parse());
	}
	
	public function execute(data:Map<String, Dynamic>) {
		var ctx = new Context();
		ctx.push();
		ctx.bind("null", null);
		ctx.bind("true", true);
		ctx.bind("false", false);
		
		for (key in data.keys()) {
			var d = data.get(key);
			ctx.bind(key, d);
		}
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
				var v:Dynamic = eval(ctx, it);
				if (v == null) return;
				try {
					var x : Dynamic = v.iterator();
					if( x.hasNext == null ) throw null;
					v = x;
				} catch( e : Dynamic ) try {
					if( v.hasNext == null ) throw null;
				} catch( e : Dynamic ) {
					throw "Cannot iter on " + v;
				}
				var v : Iterator<Dynamic> = v;
				for( i in v ) {
					ctx.push();
					ctx.bind(s, i);
					processPart(ctx, p);
					ctx.pop();
				}
			case PValue(e): ctx.append(display(eval(ctx, e)));
			case PRaw(e): ctx.append(eval(ctx, e));
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
	
	public function new() {
		stack = new CtxStack();
		tabs = "";
		buffer = new StringBuf();
		hasNewline = false;
	}
	
	public inline function push() {
		stack.add(new haxe.ds.StringMap());
	}
	
	public inline function pop() {
		return stack.pop();
	}
	
	public function bind<T>(s:String, v:T) {
		stack.first().set(s, v);
	}
	
	public function lookup(s:String, pos:hxparse.Lexer.Pos) {
		for (st in stack) {
			if (st.exists(s)) return st.get(s);
		}
		trace(formatPos(pos) + ": Warning: Unknown identifier " +s);
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