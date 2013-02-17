import String in StdString;
import templo.Ast;
import templo.Lexer;

class Main {
	
	static function main() {
		var path = Sys.args();
		if (path.length != 1)
			throw "Usage: neko hxparse.n [path to .hx file]";
		var i = sys.io.File.read(path[0], true);
		var parser = new templo.Parser(i, path[0]);
		parser.parse();
	}
	
}