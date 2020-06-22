module T = Tools
open Ergo_lib
open Ergo_wasm

let values =
  let open Core in
  [ Ejnull
  ; Ejbool false
  ; Ejbool true
  ; Ejnumber 0.
  ; Ejnumber 3.14
  ; Ejnumber infinity
  ; Ejstring (Util.char_list_of_string "hello world!")
  ; Ejstring (Util.char_list_of_string "")
  ]

let imp_identity: Core.imp_ejson =
  let open Core in
  let imp_f =
    let arg, ret = ['a'], ['r'] in
    ImpFun (arg, ImpStmtAssign (ret, ImpExprVar arg), ret)
  and name = "identity"
  in
  [Util.char_list_of_string name, imp_f]

let encode_identity_decode inst (x : Core.ejson) =
  let y : Core.ejson = Engine.invoke inst "identity" x in
  if y <> x then (
    print_endline (T.ejson_to_string x);
    print_endline (T.ejson_to_string y);
    failwith "identity"
  )

let () =
  let inst = Engine.init (Compiler.imp imp_identity) in
  List.iter (encode_identity_decode inst) values
