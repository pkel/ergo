open Wasm

let () =
  let sexpr = Arrange.module_ Ergo_wasm.Runtime.module_ in
  let str = Sexpr.to_string 72 sexpr in
  print_string str;
  let m =
    match (Parse.string_to_module str).it with
    | Textual m -> m
    | _ -> failwith "string_to_module"
  in
  try
    Wasm.Valid.check_module m
  with
  | Wasm.Valid.Invalid (_region, msg) ->
      print_endline "ERROR:";
      print_endline msg;
