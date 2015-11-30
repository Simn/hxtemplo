hxtemplo
========

Haxe port of Nicolas' [templo template engine](https://github.com/ncannasse/templo/).

### Installation

Install the library via [haxelib](http://lib.haxe.org/p/hxtemplo)
``` 
haxelib install hxtemplo 
```

### Usage
```haxe
templo.Template.fromString(s:String, ?sourceName = null);
// or
templo.Template.fromFile(path:String);
```

### Supported directives

Templo directives start with two double-dots: `::directive`. The supported
directives are:

- `::raw`
- `::if`, `::elseif` and `::else`
- `::foreach`
- `::set`
- `::fill`
- `::cond` (within node definition)
- `::repeat`` (within node definition)
- `::attr` (within node definition)
- `::switch` and `::case`
- `::use`
- `::eval`

The following directives are currently unsupported:

- `::compare`
- `~=`

### Dependencies

This Haxe library depends on [hxparse](https://github.com/Simn/hxparse).
