module T = Tools
open Ergo_lib
open Ergo_wasm

let values =
  let open T.Ejson in
  [ null
  ; true_
  ; false_
  ; number 3.14
  ; string "hello world_"
  ; string ""
  ]

(* test compilation of constants *)

let imp_const =
  let cnt = ref 0 in
  fun x ->
    let open Core in
    let () = incr cnt in
    let name = "constant" ^ (Int.to_string !cnt)
    and arg, ret = ['a'], ['r']
    in
    let fn = Util.char_list_of_string name, ImpFun (arg, ImpStmtAssign (ret, T.Imp.const x), ret)
    and test inst =
      let y = Engine.invoke inst name Ejnull in
      if y <> x then (
        print_endline (T.ejson_to_string x);
        print_endline (T.ejson_to_string y);
        failwith "constant"
      )
    in fn, test

let () =
  let l = List.map imp_const values in
  let m = List.map fst l |> Compiler.imp in
  let inst = Engine.init m in
  List.iter (fun (_, test) ->
      test inst
    ) l

(* test compilation of operators *)
let expr_expect =
  let open T.Ejson in
  let open T.Imp in
  [ not [c_false], true_
  ; not [c_true], false_
  ; not [c_null], true_
  ; not [c_string "t"], false_
  ; and_ [c_true; c_true], true_
  ; and_ [c_false; c_true], false_
  ; and_ [c_true; c_false], false_
  ; and_ [c_false; c_false], false_
  ; or_ [c_true; c_true], true_
  ; or_ [c_false; c_true], true_
  ; or_ [c_true; c_false], true_
  ; or_ [c_false; c_false], false_
  ; lt [c_number 1.0; c_number 1.0], false_
  ; lt [c_number 1.0; c_number 1.1], true_
  ; lt [c_number 1.1; c_number 1.0], false_
  ; gt [c_number 1.0; c_number 1.0], false_
  ; gt [c_number 1.0; c_number 1.1], false_
  ; gt [c_number 1.1; c_number 1.0], true_
  ; le [c_number 1.0; c_number 1.0], true_
  ; le [c_number 1.0; c_number 1.1], true_
  ; le [c_number 1.1; c_number 1.0], false_
  ; ge [c_number 1.0; c_number 1.0], true_
  ; ge [c_number 1.0; c_number 1.1], false_
  ; ge [c_number 1.1; c_number 1.0], true_
  ]

let () =
  let imp_expect =
    let cnt = ref 0 in
    fun (expr, expect) ->
      let open Core in
      let () = incr cnt in
      let name = "expect" ^ (Int.to_string !cnt)
      and arg, ret = ['a'], ['r']
      in
      let fn = Util.char_list_of_string name, ImpFun (arg, ImpStmtAssign (ret, expr), ret)
      and test inst =
        let y = Engine.invoke inst name Ejnull in
        if y <> expect then (
          print_endline name;
          print_endline (T.ejson_to_string expect);
          print_endline (T.ejson_to_string y);
          failwith "expect"
        )
      in fn, test
  in
  let l = List.map imp_expect expr_expect in
  let m = List.map fst l |> Compiler.imp in
  let inst = Engine.init m in
  List.iter (fun (_, test) ->
      test inst
    ) l

