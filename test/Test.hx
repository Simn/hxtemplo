class Test {
	
	static function main() {
		//var testPath = "http://caffeine-hx.googlecode.com/svn/trunk/projects/chxdoc/src/templates/default/class.mtt";
		var testPath = "http://localhost:2000/class.mtt";
		var http = new haxe.Http(testPath);
		http.onData = function(data) {
			function run() {
				var parser = new templo.Parser(new haxe.io.StringInput(data), "class.mtt");
				parser.parse();
			}
			haxe.Timer.measure(run);
		}
		http.onError = function(e) {
			trace(e);
		}
		http.request(false);
	}
	
}