class Enum of TypeDecl {
	my base (Maybe[Type])
	my cases (Cases)
	my isEnumClass = false
	
	on [form: (Int) = 0] (Str) {
		my buf = ""
		
		match template at Maybe[the: my template'] {
			buf
			-> [add: template'[:form]]
			-> [add: #" "]
		}
		
		buf
		-> [add: isEnumClass[yes: "enum class " no: "enum "]]
		-> [add: path[form]]
		
		match base at Maybe[the: my base'] {
			buf
			-> [add: ": "]
			-> [add: base'[form]]
		}
		
		buf
		-> [add: #" "]
		-> [add: cases[:form]]
		-> [add: #";"]
		
		return buf
	}
}