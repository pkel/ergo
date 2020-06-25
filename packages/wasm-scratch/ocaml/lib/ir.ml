type type_ = Wasm.Types.value_type

let i32 = Wasm.Types.I32Type
let i64 = Wasm.Types.I64Type
let f32 = Wasm.Types.F32Type
let f64 = Wasm.Types.F64Type

type context =
  { f : Wasm.Ast.func Table.t
  ; ty : Wasm.Ast.type_ Table.t
  ; g : global Table.t
  ; tab : table Table.t
  ; m : memory Table.t
  }

and instr = context -> Wasm.Ast.instr'

and func =
  { params : type_ list
  ; result : type_ list
  ; locals : type_ list
  ; body : instr list
  }

and table =
  { t_id: int
  ; t_min_size: int
  ; t_max_size: int option
  }

and global =
  { g_id: int
  ; mutable_: bool
  ; type_: type_
  ; init: instr list
  }

and memory =
  { m_id: int
  ; m_min_size: int
  ; m_max_size: int option
  }

let func ?(params=[]) ?(result=[]) ?(locals=[]) body =
  { params; locals; result; body}

let table =
  let cnt = ref 0 in
  fun ?max_size t_min_size ->
    let t = { t_id = !cnt; t_min_size; t_max_size = max_size} in
    incr cnt;
    t

let global =
  let cnt = ref 0 in
  fun ~mutable_ type_ init ->
    let g = { g_id = !cnt; mutable_; type_; init } in
    incr cnt; g

let memory =
  let cnt = ref 0 in
  fun ?max_size min_size ->
    let m =
      { m_id = !cnt
      ; m_min_size = min_size
      ; m_max_size = max_size
      }
    in
    incr cnt; m

type 'a export = string * 'a

type module_ =
  { start: func option
  ; funcs: func export list
  ; globals: global export list
  ; memories: memory export list
  ; tables: table export list
  ; data : (memory * int * string) list
  ; elems: (table * int * func) list
  }

module Wasm = struct
  include Wasm
  include Types
  include Values
  include Ast
  include Source
end

open (struct
  let (@@) = Wasm.Source.(@@)
  let no_region = Wasm.Source.no_region
end)

let func_to_spec_type (ctx: context) ~params ~result =
  let t = Wasm.FuncType (params, result) @@ no_region in
  let id = Table.offset ctx.ty t in
  Int32.of_int id @@ no_region

let identify (type a) (idx : a Table.t) (x : a) =
  let id = Table.offset idx x in
  Int32.of_int id @@ no_region

let table_to_spec (ctx: context) = identify ctx.tab
let memory_to_spec (ctx: context) = identify ctx.m
let global_to_spec (ctx: context) = identify ctx.g

let rec func_to_spec (ctx: context) {params; locals; result; body} =
  let f =
    let open Wasm in
    { ftype = func_to_spec_type ctx ~params ~result
    ; locals
    ; body = List.map (instr_to_spec ctx) body
    } @@ no_region
  in
  let id = Table.offset ctx.f f in
  Int32.of_int id @@ no_region

and instr_to_spec (ctx: context) (instr: instr) =
  instr ctx @@ no_region

let module_to_spec (m: module_) =
  let ctx =
    { f = Table.create ~element_size:(fun _ -> 1)
    ; g = Table.create ~element_size:(fun _ -> 1)
    ; m = Table.create ~element_size:(fun _ -> 1)
    ; ty = Table.create ~element_size:(fun _ -> 1)
    ; tab = Table.create ~element_size:(fun _ -> 1)
    }
  in
  let f_exports = List.map (fun (name, fn) ->
      let open Wasm in
      let f = func_to_spec ctx fn in
      { name = Utf8.decode name
      ; edesc = FuncExport f @@ no_region
      } @@ no_region
    ) m.funcs
  and g_exports = List.map (fun (name, g) ->
      let open Wasm in
      let g = global_to_spec ctx g in
      { name = Utf8.decode name
      ; edesc = GlobalExport g @@ no_region
      } @@ no_region
    ) m.globals
  and m_exports =
    List.map (fun (name, m) ->
        let open Wasm in
        let m = memory_to_spec ctx m in
        { name = Utf8.decode name
        ; edesc = MemoryExport m @@ no_region
        } @@ no_region
      ) m.memories
  and data =
    (* TODO: this should grow the memory's minimum size *)
    List.map (fun (m, offset, init) ->
        let open Wasm in
        { Wasm.index = memory_to_spec ctx m
        ; offset = [ Const ( I32 (Int32.of_int offset) @@ no_region) @@ no_region ] @@ no_region
        ; init
        } @@ no_region
      ) m.data
  and elems =
    (* TODO: this should grow the table's minimum size *)
    List.map (fun (t, offset, f) ->
        let open Wasm in
        { index = table_to_spec ctx t
        ; offset = [ Const ( I32 (Int32.of_int offset) @@ no_region) @@ no_region ] @@ no_region
        ; init = [ func_to_spec ctx f ]
        } @@ no_region
      ) m.elems
  in
  let globals =
    List.map (fun (_, g) ->
        { Wasm.gtype = GlobalType (g.type_, if g.mutable_ then Mutable else Immutable)
        ; value = List.map (instr_to_spec ctx) g.init @@ no_region
        } @@ no_region
      ) (Table.elements ctx.g)
  and memories =
    List.map (fun (_, m) ->
        { Wasm.mtype = MemoryType { min = Int32.of_int m.m_min_size
                                  ; max= Option.map Int32.of_int m.m_max_size
                                  }
        } @@ no_region
      ) (Table.elements ctx.m)
  and tables =
    List.map (fun (_, t) ->
        { Wasm.ttype = TableType ({ min = Int32.of_int t.t_min_size
                                  ; max= Option.map Int32.of_int t.t_max_size
                                  }, FuncRefType)
        } @@ no_region
      ) (Table.elements ctx.tab)
  in
  { Wasm.start = Option.map (func_to_spec ctx) m.start
  ; exports = m_exports @ g_exports @ f_exports
  ; types = List.map snd (Table.elements ctx.ty)
  ; funcs = List.map snd (Table.elements ctx.f)
  ; globals
  ; tables
  ; elems
  ; memories
  ; data
  ; imports = []
  } @@ no_region

type cmp_op = Ge | Gt | Le | Lt
type pack = S8 | S16 | S32 | U8 | U16 | U32

module Intructions = struct
  open Wasm

  let nop _ = Nop
  let unreachable _ = Unreachable
  let i32_const x _ = Const (I32 x @@ no_region)
  let i32_const' x = i32_const (Int32.of_int x)
  let local_get i _ = LocalGet (Int32.of_int i @@ no_region)
  let local_set i _ = LocalSet (Int32.of_int i @@ no_region)
  let local_tee i _ = LocalTee (Int32.of_int i @@ no_region)
  let global_get x ctx = GlobalGet (global_to_spec ctx x)
  let global_set x ctx = GlobalSet (global_to_spec ctx x)
  let call x ctx = Call (func_to_spec ctx x)
  let call_indirect ?(params=[]) ?(result=[]) x ctx =
    let _ = table_to_spec ctx x in
    let t = func_to_spec_type ctx ~params ~result in
    CallIndirect (t)

  let eq ty _ =
    match ty with
    | I32Type -> Compare (I32 I32Op.Eq)
    | I64Type -> Compare (I64 I64Op.Eq)
    | F32Type -> Compare (F32 F32Op.Eq)
    | F64Type -> Compare (F64 F64Op.Eq)

  let i32s_cmp op _ =
    match op with
    | Ge -> Compare (I32 I32Op.GeS)
    | Gt -> Compare (I32 I32Op.GtS)
    | Le -> Compare (I32 I32Op.LeS)
    | Lt -> Compare (I32 I32Op.LtS)

  let i32u_cmp op _ =
    match op with
    | Ge -> Compare (I32 I32Op.GeU)
    | Gt -> Compare (I32 I32Op.GtU)
    | Le -> Compare (I32 I32Op.LeU)
    | Lt -> Compare (I32 I32Op.LtU)

  let i64s_cmp op _ =
    match op with
    | Ge -> Compare (I64 I64Op.GeS)
    | Gt -> Compare (I64 I64Op.GtS)
    | Le -> Compare (I64 I64Op.LeS)
    | Lt -> Compare (I64 I64Op.LtS)

  let i64u_cmp op _ =
    match op with
    | Ge -> Compare (I64 I64Op.GeU)
    | Gt -> Compare (I64 I64Op.GtU)
    | Le -> Compare (I64 I64Op.LeU)
    | Lt -> Compare (I64 I64Op.LtU)

  let f32_cmp op _ =
    match op with
    | Ge -> Compare (F32 F32Op.Ge)
    | Gt -> Compare (F32 F32Op.Gt)
    | Le -> Compare (F32 F32Op.Le)
    | Lt -> Compare (F32 F32Op.Lt)

  let f64_cmp op _ =
    match op with
    | Ge -> Compare (F64 F64Op.Ge)
    | Gt -> Compare (F64 F64Op.Gt)
    | Le -> Compare (F64 F64Op.Le)
    | Lt -> Compare (F64 F64Op.Lt)

  let add ty _ =
    match ty with
    | I32Type -> Binary (I32 I32Op.Add)
    | I64Type -> Binary (I64 I64Op.Add)
    | F32Type -> Binary (F32 F32Op.Add)
    | F64Type -> Binary (F64 F64Op.Add)

  let i32_and _ = Binary (I32 I32Op.And)
  let i64_and _ = Binary (I64 I64Op.And)
  let i32_or _ = Binary (I32 I32Op.Or)
  let i64_or _ = Binary (I64 I64Op.Or)

  let load m ?pack ?offset type_ ctx =
    let sz = Option.map (function
        | S8 -> Pack8, SX
        | S16 -> Pack16, SX
        | S32 -> Pack32, SX
        | U8 -> Pack8, ZX
        | U16 -> Pack16, ZX
        | U32 -> Pack32, ZX
      ) pack
    in
    let offset = Int32.of_int (Option.value ~default:0 offset) in
    let _id = memory_to_spec ctx m in
    Load {ty = type_; align=2; offset; sz}

  let if_ ?(params=[]) ?(result=[]) then_ else_ ctx =
    let t = func_to_spec_type ctx ~params ~result in
    If (VarBlockType t, List.map (instr_to_spec ctx) then_, List.map (instr_to_spec ctx) else_)

  let loop ?(result=[]) body ctx =
    let t = func_to_spec_type ctx ~params:[] ~result in
    Loop (VarBlockType t, List.map (instr_to_spec ctx) body)

  let br i _ = Br (Int32.of_int i @@ no_region)
  let br_if i _ = BrIf (Int32.of_int i @@ no_region)
end
include Intructions