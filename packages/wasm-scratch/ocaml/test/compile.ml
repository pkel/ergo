open Ergo_lib
module Ir = Ergo_wasm.Ir
module Compiler = Ergo_wasm.Compiler

module Const = struct
  open Core
  let null = ImpExprConst (Ejnull)
  let false_ = ImpExprConst (Ejbool false)
  let true_ = ImpExprConst (Ejbool true)
  let number x = ImpExprConst (Ejnumber x)
end

let expressions =
  let open Core in
  let open Const in
  [ null
  ; true_
  ; false_
  ; number 3.14
  ; ImpExprConst (Ejstring ['e'; 'r'; 'g'; 'o'])
  ; ImpExprConst (Ejstring [])
  ; ImpExprOp (EJsonOpNot, [false_])
  ; ImpExprOp (EJsonOpNot, [true_])
  ]

let m =
  let ctx = Compiler.create_context () in
  let funcs =
    List.mapi (fun i e ->
        "f" ^ Int.to_string i, Ir.(func ~result:[i32] (Compiler.expr ctx e))
      ) expressions
  in
  Compiler.module_ ctx funcs

let () =
  Wasm.Print.module_ stdout 72 (Ir.compile m)

