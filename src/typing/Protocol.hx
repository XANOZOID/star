package typing;

class Protocol extends Namespace {
	final members: Array<Member> = [];
	final methods: Array<Method> = [];
	final inits: Array<Init> = [];
	final operators: Array<Operator> = [];
	var defaultInit: Option<DefaultInit> = None;
	var deinit: Option<Deinit> = None;

	static function fromAST(lookup, ast: parsing.ast.decls.Protocol) {
		final protocol = new Protocol({
			lookup: lookup,
			span: ast.span,
			name: ast.name,
			params: []
		});

		for(typevar in ast.generics.mapArray(a -> TypeVar.fromAST(protocol, a))) {
			protocol.typevars.add(typevar.name.name, typevar);
		}

		if(ast.params.isSome()) {
			protocol.params = ast.params.value().of.map(param -> protocol.makeTypePath(param));
		}

		if(ast.parents.isSome()) {
			for(parent in ast.parents.value().parents) {
				protocol.parents.push(protocol.makeTypePath(parent));
			}
		}

		for(attr => span in ast.attrs) switch attr {
			case IsHidden(_) if(protocol.hidden.isSome()): protocol.errors.push(Errors.duplicateAttribute(protocol, ast.name.name, "hidden", span));
			case IsHidden(None): protocol.hidden = Some(None);
			case IsHidden(Some(outsideOf)): protocol.hidden = Some(Some(protocol.makeTypePath(outsideOf)));

			case IsFriend(_) if(protocol.friends.length != 0): protocol.errors.push(Errors.duplicateAttribute(protocol, ast.name.name, "friend", span));
			case IsFriend(One(friend)): protocol.friends.push(protocol.makeTypePath(friend));
			case IsFriend(Many(_, friends, _)): for(friend in friends) protocol.friends.push(protocol.makeTypePath(friend));

			case IsSealed(_) if(protocol.sealed.isSome()): protocol.errors.push(Errors.duplicateAttribute(protocol, ast.name.name, "sealed", span));
			case IsSealed(None): protocol.sealed = Some(None);
			case IsSealed(Some(outsideOf)): protocol.sealed = Some(Some(protocol.makeTypePath(outsideOf)));
		}

		for(decl in ast.body.of) switch decl {
			case DMember(m) if(m.attrs.exists(IsStatic)): protocol.staticMembers.push(Member.fromAST(protocol, m));
			case DMember(m): protocol.members.push(Member.fromAST(protocol, m));

			case DModule(m): protocol.addTypeDecl(Module.fromAST(protocol, m));

			case DClass(c): protocol.addTypeDecl(Class.fromAST(protocol, c));

			case DProtocol(p): protocol.addTypeDecl(Protocol.fromAST(protocol, p));
			
			case DKind(k): protocol.addTypeDecl(Kind.fromAST(protocol, k));

			case DAlias(a): protocol.addTypeDecl(Alias.fromAST(protocol, a));

			case DCategory(c): protocol.categories.push(Category.fromAST(protocol, c));

			case DMethod(m) if(m.attrs.exists(IsStatic)): StaticMethod.fromAST(protocol, m).forEach(x -> protocol.staticMethods.push(x));
			case DMethod(m): protocol.methods.push(Method.fromAST(protocol, m));

			case DInit(i): protocol.inits.push(Init.fromAST(protocol, i));

			case DOperator(o): Operator.fromAST(protocol, o).forEach(x -> protocol.operators.push(x));

			case DDefaultInit(i) if(protocol.staticInit.isSome()): protocol.staticInit = Some(StaticInit.fromAST(protocol, i));
			case DDefaultInit(i): protocol.defaultInit = Some(DefaultInit.fromAST(protocol, i));
			
			case DDeinit(d) if(protocol.staticDeinit.isSome()): protocol.staticDeinit = Some(StaticDeinit.fromAST(protocol, d));
			case DDeinit(d): protocol.deinit = Some(Deinit.fromAST(protocol, d));
			
			default: protocol.errors.push(Errors.unexpectedDecl(protocol, ast.name.name, decl));
		}

		return protocol;
	}

	override function hasErrors() {
		return super.hasErrors()
			|| members.some(m -> m.hasErrors())
			|| methods.some(m -> m.hasErrors())
			|| inits.some(i -> i.hasErrors())
			|| operators.some(o -> o.hasErrors());
	}

	override function allErrors() {
		var result = super.allErrors();
		
		for(member in members) result = result.concat(member.allErrors());
		for(method in methods) result = result.concat(method.allErrors());
		for(init in inits) result = result.concat(init.allErrors());
		for(op in operators) result = result.concat(op.allErrors());

		return result;
	}

	inline function declName() {
		return "class";
	}
}