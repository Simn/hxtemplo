package templo;

import templo.Ast;
import templo.Token;

class Converter {
	static public var macros:Map<String, Macro> = new Map();

	static var ws = ~/[\r\n\t]+/g;
	
	var blockStack:BlockStack;
	
	static public function toAst(c:Content) {
		return new Converter().content(c);
	}
	
	static function error(s:String, p:hxparse.Position) {
		throw p + ": " +s;
	}
	
	function new() {
		blockStack = new BlockStack();
	}
		
	function content(c:Content) {
		if (c.length == 0) return PBlock(new List());
		pushBlock(BTNormal, c[0].pos);
		for (elt in c) {
			process(elt);
		}
		var b = popBlock();
		if (b.type != BTNormal) {
			error("Unclosed " +b, b.pos);
		}
		return mkBlock(b.elements);
	}
		
	function push(a:Part) {
		blockStack.first().elements.add(a);
	}
	
	function pushBlock(type:BlockType, pos) {
		blockStack.add(new Block(type, pos));
	}
	
	function popBlock() {
		return blockStack.pop();
	}
	
	function process(elt:Elt) {
		switch(elt.def) {
			case XNode(n): push(PNode(node(n)));
			case XMacroCall(s, cl): push(PMacroCall(s, cl.map(content)));
			case XMacroDef(m): defineMacro(m);
			case XComment(s): push(PComment(s));
			case XData(d):
				var d = ws.replace(d, "");
				if (d.length > 0) push(PData(d));
			case XCData(d):
				for (elt in d) process(elt);
			case XConstr(c): construct(c);
		}
	}
	
	function mkBlock(el:List<Part>) {
		return if (el.length == 1) el.first();
		else PBlock(el);
	}
	
	function construct(c:Construct) {
		switch(c.def) {
			case CRaw(e):
				push(PRaw(e));
			case CValue(e):
				push(PValue(e));
			case CIf(e):
				pushBlock(BTIf(e), c.pos);
			case CElseIf(e):
				switch(popBlock()) {
					case b = { type: BTIf(_) | BTElseif(_) } : pushBlock(BTElseif(b, e), c.pos);
					case _: error("Unexpected elseif", c.pos);
				}
			case CElse:
				var b = popBlock();
				switch(b.type) {
					case BTIf(_) | BTElseif(_):
						pushBlock(BTElse(b), c.pos);
					case _:
						error("Unexpected else", c.pos);
				}
			case CForeach(s, e1):
				pushBlock(BTForeach(s, e1), c.pos);
			case CEnd:
				function unwrap(block:Block, prev:Part) {
					return switch(block.type) {
						case BTIf(e): PIf(e, mkBlock(block.elements), prev);
						case BTElse(bt): unwrap(bt, mkBlock(block.elements));
						case BTElseif(bt, e): unwrap(bt, PIf(e, mkBlock(block.elements), prev));
						case _: throw "assert";
					}
				}
				var b = popBlock();
				switch(b.type) {
					case BTNormal | BTSwitch(_): error("Unexpected end", c.pos);
					case BTForeach(s, e): push(PForeach(s, e, mkBlock(b.elements)));
					case BTFill(s): push(PFill(s, mkBlock(b.elements)));
					case BTIf(_) | BTElseif(_) | BTElse(_): push(unwrap(b, null));
					case BTUse(e): push(PUse(e, mkBlock(b.elements)));
					case BTCase(b2,i):
						// TODO: make this less idiotic
						var cases = [];
						var cases2 = [];
						if (i == -1) cases2.push(mkBlock(b.elements));
						else cases[i] = mkBlock(b.elements);
						var b = b2;
						while (true) {
							switch(b.type) {
								case BTCase(b2,i):
									if (i == -1) cases2.push(mkBlock(b.elements));
									else cases[i] = mkBlock(b.elements);
									b = b2;
								case BTSwitch(e):
									cases2.reverse();
									for (c in 0...cases.length) {
										if (cases[i] != null) cases2[i] = cases[i];
									}
									push(PSwitch(e, cases2, mkBlock(b.elements)));
									break;
								case b: throw "assert";
							}
						}
				}
			case CSet(s, e1):
				push(PSet(s, e1));
			case CFill(s):
				pushBlock(BTFill(s), c.pos);
			case CSwitch(e):
				pushBlock(BTSwitch(e), c.pos);
			case CCase(i):
				var b = popBlock();
				switch(b.type) {
					case BTSwitch(_) | BTCase(_): pushBlock(BTCase(b, i), c.pos);
					case _: error("Unexpected case", c.pos);
				}
			case CUse(e): pushBlock(BTUse(e), c.pos);
			case CEval(e): push(PEval(e));
			case cd = (CEval(_) | CCompare | CCompareWith):
				throw 'Not implemented yet: $cd at ${c.pos}';
		}
	}
	
	function node(node:TNode) {
		return new Node(
			node.node,
			node.attributes.map(function(a) return new Named(a.name, content(a.content))),
			node.macros.map(function(m) return new Named(m.name, m.cl.map(content))),
			node.cond,
			node.repeat == null ? null : new Named(node.repeat.name, node.repeat.expr),
			node.attrs.map(function(a) return new Named(a.name, a.expr)),
			node.content == null ? null : content(node.content),
			node.ignore);
	}
	
	function defineMacro(m:TMacro) {
		switch [m.mode, m.content] {
			case [MNormal, MContent(c)]:
				macros.set(m.name, new Macro(content(c), m.args.map(function(arg) return new Named(arg.name, arg.opt))));
			case _: throw "I have no idea what these modes are";
		}
	}
}

enum BlockType {
	BTNormal;
	BTIf(e:Expr);
	BTElseif(b:Block, e:Expr);
	BTElse(b:Block);
	BTForeach(s:String, e:Expr);
	BTFill(s:String);
	BTSwitch(e:Expr);
	BTCase(b:Block, i:Int);
	BTUse(e:Expr);
}

class Block {
	public var type: BlockType;
	public var elements: List<Part>;
	public var pos:hxparse.Position;
	
	public function new(type:BlockType, pos) {
		this.type = type;
		elements = new List();
		this.pos = pos;
	}
	
	public function toString() {
		return switch(type) {
			case BTNormal: "{}";
			case BTIf(_): "if";
			case BTElseif(_): "elseif";
			case BTElse(_): "else";
			case BTForeach(_): "foreach";
			case BTFill(_): "fill";
			case BTSwitch(_): "switch";
			case BTCase(_): "case";
			case BTUse(_): "use";
		}
	}
}

typedef BlockStack = haxe.ds.GenericStack<Block>;