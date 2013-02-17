class Test {
	
	static function main() {
		//var testPath = "http://caffeine-hx.googlecode.com/svn/trunk/projects/chxdoc/src/templates/default/class.mtt";
		var testPath = "http://localhost:2000/class.mtt";
		var http = new haxe.Http(testPath);
		http.onData = function(data) {
			var parser = new templo.Parser(new haxe.io.StringInput(data), "class.mtt");
			var stamp = haxe.Timer.stamp();
			trace("Starting");
			parser.parse();
			trace('Elapsed: ${haxe.Timer.stamp() - stamp}');
		}
		http.onError = function(e) {
			trace(e);
		}
		http.request(false);
	}
	
}