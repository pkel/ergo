open Import

module type CONTEXT = sig
  val memory : Ir.memory
  val alloc_p : Ir.global
  val constants : string Table.t
end

module type LIB = sig
  val const : data -> Ir.instr
  val c_true : Ir.instr
  val c_false : Ir.instr

  val not : Ir.func
  val or_ : Ir.func
  val and_ : Ir.func
end

module Make (C : CONTEXT) : LIB = struct
  let const x : Ir.instr =
    let s = Ejson.encode x |> Bytes.to_string in
    let offset = Table.offset C.constants s in
    Ir.i32_const' offset

  let c_true = const (Ejbool true)
  let c_false = const (Ejbool false)

  (* null and false are "falsy".
   * null has tag 0. false has tag 1. *)
  let not =
    let open Ir in
    func ~params:[i32] ~result:[i32]
      [ local_get 0
      ; load C.memory i32
      ; i32_const' 1
      ; i32_le_u
      ; if_ ~result:[i32]
          [ c_true ]
          [ c_false ]
      ]

  let boolean_binary cmp =
    let open Ir in
    func ~params:[i32; i32] ~result:[i32]
      [ local_get 0
      ; load C.memory i32
      ; i32_const' 1
      ; i32_gt_u
      ; local_get 1
      ; load C.memory i32
      ; i32_const' 1
      ; i32_gt_u
      ; cmp
      ; if_ ~result:[i32]
          [ c_true ]
          [ c_false ]
      ]

  let and_ = boolean_binary Ir.i32_and
  let or_ = boolean_binary Ir.i32_or
end

type t = (module LIB)

let make ~memory ~alloc_p ~constants : t =
  let module C = struct
    let memory = memory
    let alloc_p = alloc_p
    let constants = constants
  end in
  (module Make (C) : LIB)
