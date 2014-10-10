package templo;

import templo.Token;

enum Part {
	PValue(e:Expr);
	PRaw(e:Expr);
	PBlock(al:List<Part>);
	PData(s:String);
	PNode(node:Node);
	PComment(s:String);
	PForeach(s:String, it:Expr, body:Part);
	PIf(e1:Expr, e2:Part, e3:Null<Part>);
	PSwitch(e1:Expr, cases:Array<Part>, def:Null<Part>);
	PSet(s:String, e1:Expr);
	PFill(s:String, body:Part);
	PMacroCall(s:String, cl:Array<Part>);
	PUse(e:Expr, body:Part);
	PEval(e:Expr);
}

class Named<T> {
	public var name:String;
	public var t:T;

	public function new(name, t) {
		this.name = name;
		this.t = t;
	}
}

class Node {
	public var node:String;
	public var attributes:Array<Named<Part>>;
	public var macros:Array<Named<Array<Part>>>;
	public var cond:Null<Expr>;
	public var repeat:Null<Named<Expr>>;
	public var attrs:Array<Named<Expr>>;
	public var content:Null<Part>;
	public var ignore:Bool;

	public function new(node, attributes, macros, cond, repeat, attrs, content, ignore) {
		this.node = node;
		this.attributes = attributes;
		this.macros = macros;
		this.cond = cond;
		this.repeat = repeat;
		this.attrs = attrs;
		this.content = content;
		this.ignore = ignore;
	}
}

class Macro {
	public var part:Part;
	public var args:Array<Named<Bool>>;

	public function new(part, args) {
		this.part = part;
		this.args = args;
	}
}