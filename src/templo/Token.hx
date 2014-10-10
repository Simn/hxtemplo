package templo;
import hxparse.Position in Pos;

enum TokenDef {
	Comment(v:String);
	Node(v:String);
	Macro(v:String);
	DoubleDot;
	Data(v:String);
	EndNode(v:String);
	CDataBegin;
	CDataEnd;
	NodeContent(v:Bool);
	Quote(v:Bool);
	Dot;
	Int(v:Int);
	Float(v:String);
	String(v:String);
	Ident(v:String);
	Kwd(v:Keyword);
	Comma;
	ParentOpen;
	ParentClose;
	BraceOpen;
	BraceClose;
	BracketOpen;
	BracketClose;
	Op(v:Op);
	Unop(v:Unop);
	Question;
	Eof;
}

class Token {
	public var tok: TokenDef;
	public var pos: Pos;

	public function new(tok,pos) {
		this.tok = tok;
		this.pos = pos;
	}
}

enum Keyword {
	If;
	Else;
	Var;
	While;
	Do;
	For;
	Break;
	Continue;
	Function;
	Return;
	This;
	Try;
	Catch;
	Default;
	Switch;
	Case;
	Ignore;
	Literal;
}

enum Op {
	OpAdd;
	OpMult;
	OpDiv;
	OpSub;
	OpAssign;
	OpEq;
	OpNotEq;
	OpGt;
	OpGte;
	OpLt;
	OpLte;
	OpAnd;
	OpOr;
	OpXor;
	OpBoolAnd;
	OpBoolOr;
	OpShl;
	OpShr;
	OpUShr;
	OpMod;
	OpCompare;
}

enum Unop {
	Increment;
	Decrement;
	Not;
	Neg;
}


enum Constant {
	CInt(c:Int);
	CString(c:String);
	CFloat(c:String);
}

enum ExprDef {
	VConst(c:Constant);
	VIdent(s:String);
	VVar(v:String);
	VIf(eif:Expr, ethen:Expr, eelse:Null<Expr>);
	VBinop(op:Op,e1:Expr,e2:Expr);
	VUnop(op:Unop,postfix:Bool,e1:Expr);
	VCall(e1:Expr, el:Array<Expr>);
	VParent(e1:Expr);
	VField(e1:Expr, s:String);
	VArray(e1:Expr,e2:Expr);
	VArrayDecl(el:Array<Expr>);
	VBool(e:Expr);
	VLiteral(e:Expr);
	VObject(fl:Array<{name:String, expr:Expr}>);
}

typedef Expr = {
	expr: ExprDef,
	pos: Pos
}

typedef Content = Array<Elt>;

enum ConstructDef {
	CValue(e:Expr);
	CRaw(e:Expr);
	CIf(e:Expr);
	CElseIf(e:Expr);
	CElse;
	CForeach(s:String, e1:Expr);
	CFill(e:String);
	CUse(e:Expr);
	CSet(s:String, e1:Expr);
	CEval(e:Expr);
	CEnd;
	CSwitch(e:Expr);
	CCase(e:Int);
	CCompare;
	CCompareWith;
}

typedef Construct = {
	def: ConstructDef,
	pos: Pos
}

typedef TNode = {
	node : String,
	attributes : Array<{name:String, content:Content}>,
	macros : Array<{name:String, pos:Pos, cl:Array<Content>}>,
	cond : Null<Expr>,
	repeat : Null<{name:String, expr:Expr}>,
	attrs : Array<{name:String, expr:Expr}>,
	content : Null<Content>,
	ignore : Bool
}

enum MacroContent {
	MContent(c:Content);
	MAttr(cl:Array<{name:String, content:Content}>);
}

enum MacroMode {
	MNormal;
	MLiteral;
	MGrammar;
}

typedef TMacro = {
	mode : MacroMode,
	name : String,
	args : Array<{name:String, mode:MacroMode, opt:Bool}>,
	content : MacroContent
}

enum EltDef {
	XNode(node:TNode);
	XMacroCall(s:String, cl:Array<Content>);
	XMacroDef(m:TMacro);
	XComment(s:String);
	XData(d:String);
	XCData(d:Content);
	XConstr(c:Construct);
}

typedef Elt = {
	def:EltDef,
	pos:Pos
}