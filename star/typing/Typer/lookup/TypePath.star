use #[
	Ident
	Delims
	;Type.Seg
] from: Parser
use Seg from: Parser.Type

alias TypePath (Parser.Type) {
	on [toLookupPath: lookup (TypeLookup)] (Tuple[Int, LookupPath]) {
		match this {
			at This[blank: _] || This[blank: _ args: _] => throw "error!"
			at This[leading: my leading segs: my segs] {
				return #{
					leading.length
					segs[TypePath mapSegs: lookup]
				}
			}
		}
	}

	on [toType: source (TypeLookup)] (Type) {
		match this {
			at This[blank: my span] {
				return Type[blank: span]
			}

			at This[blank: my span args: Delims[of: my args]] {
				return Type[
					span: Maybe[the: this.span]
					type: Type[blank: span]
					args: args[collect: $0[TypePath][toType: source]]
				]
			}

			at This[leading: my leading segs: my segs] {
				return Type[
					span: this.span
					depth: leading.length
					lookup: segs[mapSegs: source]
					:source
				]
			}
		}
	}
}

category TypePath for Array[Seg] {
	on [mapSegs: source (TypeLookup)] (LookupPath) {
		return this[LookupPath collect: {|seg|
			match this {
				at Seg[name: Ident #{my span, my name}] {
					return #{span, name, #[]}
				}

				at Seg[name: Ident #{my span, my name} args: Delims[of: my args]] {
					return #{
						span
						name
						args[collect: source[makeTypePath: $.0[TypePath]]]
					}
				}
			}
		}]
	}
}