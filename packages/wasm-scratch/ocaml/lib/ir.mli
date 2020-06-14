type type_

val i32: type_
val i64: type_
val f64: type_

type instr

val nop : instr
val i32_const : int32 -> instr
val i32_const' : int -> instr
val i32_add : instr
val local_get : int -> instr
val local_set : int -> instr
val local_tee : int -> instr

type func

val func:
  ?params: type_ list ->
  ?result: type_ list ->
  ?locals: type_ list -> instr list -> func

val call: func -> instr

type global

val global: mutable_:bool -> type_ -> instr list -> global

val global_get : global -> instr
val global_set : global -> instr

type module_ =
  { start: func option
  ; funcs: (string * func) list
  ; globals: (string * global) list
  ; data : (int * string) list
  }

val compile: module_ -> Wasm.Ast.module_
