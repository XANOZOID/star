package typing;

typedef IEffects = ImmutableEnumSet<Effect>;

enum Effect {
	ETypevar(typevar: TypeVar, ctx: Ctx);
	EUnion(effects: IEffects);
}

typedef Entries = ImmutableMap<TypeVar, IEffects>;

@:publicFields @:structInit class _Effects {
	final adds: Entries;
	final removes: Entries;

	inline function new(adds: Entries, removes: Entries) {
		this.adds = adds;
		this.removes = removes;
	}
}

@:forward
abstract Effects(_Effects) from _Effects {
	public static final empty: Effects = {adds: new Entries(), removes: new Entries()};

	public var adds(get, never): Entries; inline function get_adds() return this.adds;
	public var removes(get, never): Entries; inline function get_removes() return this.removes;


	public function add(typevar: TypeVar, effect: Effect): Effects {
		removes[typevar]._match(
			at(effects!, when(effects.contains(effect))) => {
				throw "Cannot add effect which is already negated!";
			},
			_ => {
				return {
					adds: adds.set(typevar, {
						adds[typevar]._match(
							at(effects!) => effects + effect,
							_ => new IEffects() + effect
						);
					}),
					removes: removes
				};
			}
		);
	}

	public function remove(typevar: TypeVar, effect: Effect): Effects {
		adds[typevar]._match(
			at(effects!, when(effects.contains(effect))) => {
				throw "Cannot remove effect which already exists!";
			},
			_ => {
				return {
					adds: adds,
					removes: removes.set(typevar, {
						removes[typevar]._match(
							at(effects!) => effects + effect,
							_ => new IEffects() + effect
						);
					})
				};
			}
		);
	}


	public function addsFor(typevar: TypeVar): IEffects {
		return adds[typevar]._or(
			new IEffects()
		);
	}

	public function removesFor(typevar: TypeVar): IEffects {
		return removes[typevar]._or(
			new IEffects()
		);
	}


	public function negate(): Effects {
		return {
			adds: removes,
			removes: adds
		};
	}


	@:op(A + B)
	function combine(other: Effects): Effects {
		if(this == empty) return other;
		else if(other == empty) return this;
		else {
			// TODO: use mutable maps without too much overhead

			var adds2 = adds;
			var removes2 = removes;

			for(typevar => effects in other.adds) {
				// make sure `removes` doesn't have any conflicting effects with `adds`
				removes[typevar]._and(effects2 => {
					if(effects2.containsAny(effects)) {
						throw "Conflicting effects!";
					}
				});

				adds2[typevar] = {
					adds[typevar]._match(
						at(effects2!) => effects2 | effects,
						_ => effects
					);
				};
			}

			for(typevar => effects in other.removes) {
				// we don't need to check for conflicts because we already did that in the prev loop

				removes2[typevar] = {
					removes[typevar]._match(
						at(effects2!) => effects2 | effects,
						_ => effects
					);
				};
			}

			return {
				adds: adds2,
				removes: removes2
			};
		}
	}
	
	/*@:op(A == B)
	function eq(other: Effects): Bool {
		return this == other || (
			adds == other.adds
			&& removes == other.removes
		);
	}

	@:op(A != B)
	function ne(other: Effects): Bool {
		return this != other || (
			adds != other.adds
			|| removes != other.removes
		);
	}*/
}