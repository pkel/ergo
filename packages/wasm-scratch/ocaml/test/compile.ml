open Ergo_wasm.Compiler

let m = new Wasm_module.t

let expressions =
  let open Ergo_lib.Core in
  [ ImpExprConst (Ejnull)
  ; ImpExprConst (Ejbool false)
  ; ImpExprConst (Ejbool true)
  ; ImpExprConst (Ejnumber 3.14)
  ; ImpExprConst (Ejstring ['e'; 'r'; 'g'; 'o'])
  ; ImpExprConst (Ejstring [])
  ]

let () =
  List.iter (fun x ->
      ignore (m#func ~result:[I32Type] (expr x m))
    ) expressions;
  Wasm.Print.module_ stdout 72 m#return

