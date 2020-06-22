open Ergo_lib
open Ergo_wasm

module Const = struct
  open Core
  let null = ImpExprConst (Ejnull)
  let false_ = ImpExprConst (Ejbool false)
  let true_ = ImpExprConst (Ejbool true)
  let number x = ImpExprConst (Ejnumber x)
  let string x = ImpExprConst (Ejstring (Util.char_list_of_string x))
end

let expressions =
  let open Core in
  let open Const in
  [ null
  ; true_
  ; false_
  ; number 3.14
  ; string "ergo"
  ; string ""
  ; ImpExprOp (EJsonOpNot, [false_])
  ; ImpExprOp (EJsonOpNot, [true_])
  ; ImpExprOp (EJsonOpNot, [null])
  ; ImpExprOp (EJsonOpAnd, [false_; number 1.])
  ; ImpExprOp (EJsonOpOr, [true_; false_])
  ]

let m =
  let imp : Core.imp_ejson =
    List.mapi (fun i e ->
        let open Core in
        let name = "f" ^ Int.to_string i
        and arg, ret = ['a'], ['r']
        in
        let stmt = ImpStmtAssign (ret, e)
        in Util.char_list_of_string name, ImpFun (arg, stmt, ret)
      ) expressions
  in
  Compiler.imp imp

let () =
  Wasm.Print.module_ stdout 72 m

