exception Unsupported of string
let unsupported : type a. string -> a = fun s -> raise (Unsupported s)

include Ergo_lib

type data = Core.ejson
type op = Core.ejson_op
type runtime = Core.ejson_runtime_op
type imp = Core.imp_ejson
