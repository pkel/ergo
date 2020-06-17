type type_

val i32: type_
val i64: type_
val f32: type_
val f64: type_

type instr

val nop : instr
val i32_const : int32 -> instr
val i32_const' : int -> instr
val add : type_ -> instr

(** {2} local variables *)

val local_get : int -> instr
val local_set : int -> instr
val local_tee : int -> instr

(** {2} functions *)

type func

val func:
  ?params: type_ list ->
  ?result: type_ list ->
  ?locals: type_ list -> instr list -> func

val call: func -> instr

(** {2} global variables *)

type global

val global: mutable_:bool -> type_ -> instr list -> global

val global_get : global -> instr
val global_set : global -> instr

(** {2} memory *)

type memory

val memory: ?max_size:int -> int -> memory
val load : ?offset:int -> memory -> type_ -> instr

(** {2} module *)

type 'a export = string * 'a

type module_ =
  { start: func option
  ; funcs: func export list
  ; globals: global export list
  ; memories: memory export list
  ; data : (memory * int * string) list
  }

val compile: module_ -> Wasm.Ast.module_
