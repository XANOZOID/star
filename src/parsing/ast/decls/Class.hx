package parsing.ast.decls;

import text.Span;

enum ClassAttr {
	IsHidden(outsideOf: Option<Type>);
	IsFriend(spec: TypesSpec);
	IsNative(_begin: Span, spec: Array<{label: Ident, expr: Expr}>, _end: Span);
	IsStrong;
	IsUncounted;
}

@:structInit
@:publicFields
class Class {
	final generics: List<GenericParam>;
	final span: Span;
	final name: Ident;
	final params: TypeParams;
	final parents: Parents;
	final attrs: Map<ClassAttr, Span>;
	final body: DeclBody;
}