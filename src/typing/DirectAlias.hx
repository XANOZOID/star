package typing;

import typing.Traits;

class DirectAlias extends Alias {
	var type: Type;

	static function fromAST(lookup: ITypeLookup, ast: parsing.ast.decls.Alias) {
		final alias = new DirectAlias({
			lookup: lookup,
			span: ast.span,
			name: ast.name,
			params: [],
			type: null // Hack for partial initialization
		});

		for(typevar in ast.generics.mapArray(a -> TypeVar.fromAST(alias, a))) {
			alias.typevars.add(typevar.name.name, typevar);
		}

		switch ast.kind {
			case Direct(_, type): alias.type = alias.makeTypePath(type);
			default: throw "Error!";
		}

		if(ast.params.isSome()) {
			alias.params = ast.params.value().of.map(param -> alias.makeTypePath(param));
		}

		for(attr => span in ast.attrs) switch attr {
			case IsHidden(_) if(alias.hidden.isSome()): alias.errors.push(Errors.duplicateAttribute(alias, ast.name.name, "hidden", span));
			case IsHidden(None): alias.hidden = Some(None);
			case IsHidden(Some(outsideOf)): alias.hidden = Some(Some(alias.makeTypePath(outsideOf)));

			case IsFriend(_) if(alias.friends.length != 0): alias.errors.push(Errors.duplicateAttribute(alias, ast.name.name, "friend", span));
			case IsFriend(One(friend)): alias.friends.push(alias.makeTypePath(friend));
			case IsFriend(Many(_, friends, _)): for(friend in friends) alias.friends.push(alias.makeTypePath(friend));
			
			case IsNoinherit: alias.errors.push(Errors.invalidAttribute(alias, ast.name.name, "noinherit", span));
		}

		return alias;
	}


	override function findType(path: LookupPath, search: Search, from: Null<AnyTypeDecl>, depth = 0, cache: Cache = Nil): Null<Type> {
		if(search == Inside) {
			return type.findType(path, Inside, from, depth, cache + thisType);
		} else {
			return super.findType(path, search, from, depth, cache);
		}
	}


	// Type checking

	override function hasParentDecl(decl: TypeDecl) {
		return super.hasParentDecl(decl)
			|| type.hasParentDecl(decl);
	}
	
	override function hasChildDecl(decl: TypeDecl) {
		return super.hasChildDecl(decl)
			|| type.hasChildDecl(decl);
	}


	override function hasParentType(type2: Type) {
		return super.hasParentType(type2)
			|| type.hasParentType(type2);
	}
	
	override function hasChildType(type2: Type) {
		return super.hasChildType(type2)
			|| type.hasChildType(type2);
	}


	// Unification

	override function strictUnifyWithType(type2: Type) {
		return type.strictUnifyWithType(type);
	}


	// Attributes

	override function isNative(kind: NativeKind) {
		return type.isNative(kind);
	}

	override function isFlags() {
		return type.isFlags();
	}
	
	override function isStrong() {
		return type.isStrong();
	}

	override function isUncounted() {
		return type.isUncounted();
	}


	// Privacy

	override function canSeeMember(member: Member) {
		return type.canSeeMember(member);
	}

	override function canSeeMethod(method: AnyMethod) {
		return type.canSeeMethod(method);
	}

	
	// Effects tracking

	// TODO


	// Members

	override function instMembers(from: AnyTypeDecl) {
		return type.instMembers(from);
	}


	// Method lookup

	override function findSingleStatic(ctx: Ctx, name: String, from: AnyTypeDecl, getter = false, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return null;
		
		return type.findSingleStatic(ctx, name, from, getter, cache + thisType);
	}


	override function findMultiStatic(ctx: Ctx, names: Array<String>, from: AnyTypeDecl, setter = false, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return [];
		
		return type.findMultiStatic(ctx, names, from, setter, cache + thisType);
	}


	override function findSingleInst(ctx: Ctx, name: String, from: AnyTypeDecl, getter = false, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return null;
		
		return type.findSingleInst(ctx, name, from, getter, cache + thisType);
	}


	override function findMultiInst(ctx: Ctx, names: Array<String>, from: AnyTypeDecl, setter = false, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return [];
		
		return type.findMultiInst(ctx, names, from, setter, cache + thisType);
	}


	override function findCast(ctx: Ctx, target: Type, from: AnyTypeDecl, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return [];
		
		return type.findCast(ctx, target, from, cache + thisType);
	}


	override function findUnaryOp(ctx: Ctx, op: UnaryOp, from: AnyTypeDecl, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return null;

		return type.findUnaryOp(ctx, op, from, cache + thisType);
	}


	override function findBinaryOp(ctx: Ctx, op: BinaryOp, from: AnyTypeDecl, cache: TypeCache = Nil) {
		if(cache.contains(thisType)) return [];

		return type.findBinaryOp(ctx, op, from, cache + thisType);
	}
}