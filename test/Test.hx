enum QuestItem
{
	ITEM(id:Int);
	MONEY(amount:Int);
	XP(amount:Int);
	OTHER;
}

class Test extends haxe.unit.TestCase {
	
	static var whitespaceEreg = ~/[\t\n\r]*/g;
	
	static function main() {
		var r = new haxe.unit.TestRunner();
		r.add(new Test());
		r.run();
	}
	
	function testParse() {
		var s = '<html><body onload="Hello World">Hello World</body></html>';
		weq(s, mkt(s, {}));
	}
	
	function testReplace() {
		var s = '<html><body onload="::myValue::">::myValue::</body></html>';
		weq('<html><body onload="Hello Var">Hello Var</body></html>', mkt(s, {"myValue":"Hello Var"}));
	}
	
	function testIf() {
		var s = 'abc::if myVar == 3::def::end::ghi';
		weq('abcghi', mkt(s, {"myVar": 2}));
		weq('abcdefghi', mkt(s, {"myVar": 3}));
	}
	
	function testElse() {
		var s = 'abc::if myVar == 3::def::else::ghi::end::jkl';
		weq('abcghijkl', mkt(s, {"myVar": 2}));
		weq('abcdefjkl', mkt(s, {"myVar": 3}));
	}
	
	function testElseIf() {
		var s = 'abc::if myVar == 3::def::elseif myVar == 2::ghi::else::jkl::end::mno';
		weq('abcjklmno', mkt(s, {"myVar": 1}));
		weq('abcghimno', mkt(s, {"myVar": 2}));
		weq('abcdefmno', mkt(s, {"myVar": 3}));
	}
	
	function testCond() {
		var s = '<node1><node2 ::cond myVar == 3::>v</node2></node1>';
		weq('<node1></node1>',mkt(s, {"myVar": 1}));
		weq('<node1><node2>v</node2></node1>',mkt(s, {"myVar": 3}));
	}
	
	function testForeach() {
		var s = 'abc::foreach n myIterable::value::n::::end::def';
		weq('abcdef', mkt(s, {"myIterable": []}));
		weq('abcvalue1def', mkt(s, {"myIterable": [1]}));
		weq('abcvalue1value2value3def', mkt(s, {"myIterable": [1, 2, 3]}));
	}
	
	function testRepeat() {
		var s = '<node1><node2 ::repeat n myIterable::>value::n::</node2></node1>';
		weq('<node1></node1>', mkt(s, {"myIterable": []}));
		weq('<node1><node2>value1</node2></node1>', mkt(s, {"myIterable": [1]}));
	}
	
	function testForeachContext() {
		var s = '::foreach n myIterable::index::repeat.n.index::,number::repeat.n.number::,odd::repeat.n.odd::,even::repeat.n.even::,first::repeat.n.first::,last::repeat.n.last::::end::';
		weq("", mkt(s, {"myIterable": []}));
		weq("index0,number1,oddfalse,eventrue,firsttrue,lasttrue", mkt(s, {"myIterable": [1]}));
		weq("index0,number1,oddfalse,eventrue,firsttrue,lastfalseindex1,number2,oddtrue,evenfalse,firstfalse,lastfalseindex2,number3,oddfalse,eventrue,firstfalse,lasttrue", mkt(s, {"myIterable": [1,2,3]}));
	}
	
	function testSet() {
		var s = 'before::myValue::::set myValue=1::after::myValue::';
		weq('before2after1', mkt(s, {"myValue": 2}));
	}
	
	function testFill() {
		var s = '::fill myValue::<node1>Some code</node1>::end::Some other code,::raw myValue::';
		weq('Some other code,<node1>Some code</node1>', mkt(s, {"myValue": "foo"}));
	}
	
	function testSwitch() {
		var s = '::switch myEnum::default::case::Item ::args[0]::::case::::args[0]:: gold::case::::args[0]:: XP::end::';
		weq("default", mkt(s, {myEnum: OTHER}));
		weq("Item 12", mkt(s, {myEnum: ITEM(12)}));
		weq("13 gold", mkt(s, {myEnum: MONEY(13)}));
		weq("14 XP", mkt(s, {myEnum: XP(14)}));
	}
	
	function testUse() {
		templo.Template.fromString("abc::myValue::def", "mySource");
		var s = 'use ::use "mySource"::::end:: again.::set myValue = 9:: ::use "mySource"::::end::ok';
		weq('use abc2def again. abc9defok', mkt(s, { myValue: 2 }));
	}
	
	function testUseContent() {
		templo.Template.fromString("abc::raw __content__::def", "mySource2");
		var s = '987::use "mySource2"::1234::end::456';
		weq('987abc1234def456', mkt(s, {}));
	}
	
	function testAttr() {
		var s = '<node ::attr test myValue1:: ::attr test2 myValue2::></node>';
		weq('<node test2="9"></node>', mkt(s, { myValue2: 9 }));
		weq('<node test="17" test2="9"></node>', mkt(s, { myValue1: 17, myValue2: 9 }));
	}
	
	function testAssign() {
		var s = '::set v=1::::v::::v = 9::::v::';
		weq("199", mkt(s, {}));
		
		var s = '::set a = [1,2]::::a[0]::::a[1]::::a[0] = 9::::a[0]::::a[1]::';
		weq("12992", mkt(s, {}));
		
		var s = '::set f = { a: 1, b : 2}::::f.a::::f.b::::f.b = 9::::f.a::::f.b::';
		weq("12919", mkt(s, {}));
	}
	
	function testPrefix() {
		var s = '::set x = 1::::x::::++x::::x::';
		weq("122", mkt(s, {}));
		
		var s = '::set x = 1::::x::::--x::::x::';
		weq("100", mkt(s, {}));
		
		var s = '::set x = { v: 1 }::::x.v::::++x.v::::x.v::';
		weq("122", mkt(s, {}));
		
		var s = '::set x = { v: 1 }::::x.v::::--x.v::::x.v::';
		weq("100", mkt(s, {}));
		
		var s = '::set x = [1]::::x[0]::::++x[0]::::x[0]::';
		weq("122", mkt(s, {}));
		
		var s = '::set x = [1]::::x[0]::::--x[0]::::x[0]::';
		weq("100", mkt(s, {}));
	}
	
	function testPostfix() {
		var s = '::set x = 1::::x::::x++::::x::';
		weq("112", mkt(s, {}));
		
		var s = '::set x = 1::::x::::x--::::x::';
		weq("110", mkt(s, {}));
		
		var s = '::set x = { v: 1 }::::x.v::::x.v++::::x.v::';
		weq("112", mkt(s, {}));
		
		var s = '::set x = { v: 1 }::::x.v::::x.v--::::x.v::';
		weq("110", mkt(s, {}));
		
		var s = '::set x = [1]::::x[0]::::x[0]++::::x[0]::';
		weq("112", mkt(s, {}));
		
		var s = '::set x = [1]::::x[0]::::x[0]--::::x[0]::';
		weq("110", mkt(s, {}));
	}
	
	function mkt(s:String, map:{}) {
		return templo.Template.fromString(s).execute(map);
	}
	
	function weq(expected:String, actual:String, ?p) {
		assertEquals(whitespaceEreg.replace(expected, ""), whitespaceEreg.replace(actual, ""), p);
	}
}