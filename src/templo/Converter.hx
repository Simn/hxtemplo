package templo;

import templo.Ast;
import templo.Token;

class Converter {
	static public var macros:Map<String, Macro> = new Map();

	var blockStack:BlockStack;
	
	static public function toAst(c:Content) {
		return new Converter().content(c);
	}
	
	function new() {
		blockStack = new BlockStack();
	}
		
	function content(c:Content) {
		pushBlock(BTNormal);
		for (elt in c) {
			process(elt);
		}
		return mkBlock(popBlock().elements);
	}
	
	function error(s:String, p:hxparse.Lexer.Pos) {
		throw p + ": " +s;
	}	
	
	function push(a:Part) {
		blockStack.first().elements.push(a);
	}
	
	function pushBlock(type:BlockType) {
		blockStack.add(new Block(type));
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
			case XData(d): push(PData(d));
			case XCData(d): throw "niy";
			case XConstr(c): construct(c);
		}
	}
	
	function mkBlock(el:Array<Part>) {
		return switch(el) {
			case [e]: e;
			case _: PBlock(el);
		}		
	}
	
	function construct(c:Construct) {
		switch(c.def) {
			case CRaw(e):
				push(PRaw(e));
			case CValue(e):
				push(PValue(e));
			case CIf(e):
				pushBlock(BTIf(e));
			case CElseIf(e):
				switch(popBlock()) {
					case b = { type: BTIf(_) | BTElseif(_) } : pushBlock(BTElseif(b, e));
					case _: error("Unexpected elseif", c.pos);
				}
			case CElse:
				var b = popBlock();
				switch(b.type) {
					case BTIf(_) | BTElseif(_):
						pushBlock(BTElse(b));
					case _:
						error("Unexpected else", c.pos);
				}
			case CForeach(s, e1):
				pushBlock(BTForeach(s, e1));				
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
					case BTCase(_,_):
						var cases = [];
						while (true) {
							switch(b.type) {
								case BTCase(b2,_):
									cases.push(mkBlock(b.elements));
									b = b2;
								case BTSwitch(e):
									cases.reverse();
									push(PSwitch(e, cases, mkBlock(b.elements)));
									break;
								case b: throw "assert";
							}
						}
				}
			case CSet(s, e1):
				push(PSet(s, e1));
			case CFill(s):
				pushBlock(BTFill(s));
			case CSwitch(e):
				pushBlock(BTSwitch(e));
			case CCase(i):
				var b = popBlock();
				switch(b.type) {
					case BTSwitch(_) | BTCase(_): pushBlock(BTCase(b, i));
					case _: error("Unexpected case", c.pos);
				}
			case CUse(e): pushBlock(BTUse(e));
			case cd = (CUse(_) | CEval(_) | CCompare | CCompareWith):
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
	public var elements: Array<Part>;
	
	public function new(type:BlockType) {
		this.type = type;
		elements = [];
	}
}

typedef BlockStack = haxe.ds.GenericStack<Block>;