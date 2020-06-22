open Import

type instance

val init: Wasm.Ast.module_ -> instance

val invoke: instance -> string -> data -> data
