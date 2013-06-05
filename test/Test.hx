class Test {
	
	static function main() {
		new templo.Template(new haxe.io.StringInput(haxe.Resource.getString("macros.mtt")), "macros.mtt");
		var tpl = new templo.Template(new haxe.io.StringInput(haxe.Resource.getString("class.mtt")), "class.mtt");
		var str = tpl.execute([
			"title" => "My docs",
			"config" => {
				title: "My Class"
			},
			"build" => {
				comment: "I'm the greatest"
			},
			"superClassHtml" => "super class!",
			"webmeta" => {
				keywords: ["foo", "bar"]
			},
			"methods" => [ {
				{
					name: "myFunction"
				}
			}]
		]);
		trace(str);
	}
	
}