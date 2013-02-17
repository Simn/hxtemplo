package templo;
import templo.Ast;

class Debug {
	static public function printContent(content:Content) {
		return content == null ? "" : [for (c in content ) {
			switch(c.def) {
				case XNode(node): printNode(node);
				case XMacroCall(s, _): '(MacroCall $s)';
				case XMacroDef(_): "macro";
				case XComment(s): '(Comment $s)';
				case XData(d): '(Data "$d")';
				case XCData(c): '(Content ${printContent(c)})';
				case XConstr(c): '(Construct ${printConstruct(c)})';
			}
		}].join("\n");
	}
	
	static public function printNode(node:Node) {
		return '<${node.node}>\n${printContent(node.content)}</${node.node}>';
	}
	
	static public function printConstruct(c:Construct) {
		return c.def.getName();
	}
}