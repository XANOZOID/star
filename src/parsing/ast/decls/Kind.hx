package parsing.ast.decls;

import text.Span;

enum KindAttr {
	IsHidden(outsideOf: Option<Type>);
	IsFriend(spec: TypesSpec);
	IsFlags;
	IsStrong;
	IsUncounted;
}

@:structInit
@:publicFields
class Kind {
	final generics: List<GenericParam>;
	final span: Span;
	final name: Ident;
	final params: TypeParams;
	final repr: Option<Type>;
	final parents: Parents;
	final attrs: Map<KindAttr, Span>;
	final body: DeclBody;
}