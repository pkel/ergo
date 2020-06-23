module Index : sig
  type 'a t

  val create : unit -> 'a t
  val id : 'a t -> 'a -> int
  val elements : 'a t -> 'a array
end = struct
  type 'a t = ('a, int) Hashtbl.t * int ref

  let create () = Hashtbl.create 7, ref 0

  let id (ht, size) x =
    match Hashtbl.find_opt ht x with
    | Some id -> id
    | None ->
      let id = !size in
      Hashtbl.add ht x id;
      incr size;
      id

  let elements (ht, size) =
    let a = Array.make !size None in
    Hashtbl.iter (fun el id -> a.(id) <- Some el) ht;
    Array.map Option.get a
end

type type_ = Wasm.Types.value_type

let i32 = Wasm.Types.I32Type
let i64 = Wasm.Types.I64Type
let f32 = Wasm.Types.F32Type
let f64 = Wasm.Types.F64Type

type context =
  { f : Wasm.Ast.func Index.t
  ; ty : Wasm.Ast.type_ Index.t
  ; g : global Index.t
  ; tab : table Index.t
  ; m : memory Index.t
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

let func_to_spec_type (ctx: context) ~params ~result =
  let open Wasm in
  let t = FuncType (params, result) @@ no_region in
  let id = Index.id ctx.ty t in
  Int32.of_int id @@ no_region

let identify (type a) (idx : a Index.t) (x : a) =
  let open Wasm in
  let id = Index.id idx x in
  Int32.of_int id @@ no_region

let table_to_spec (ctx: context) = identify ctx.tab
let memory_to_spec (ctx: context) = identify ctx.m
let global_to_spec (ctx: context) = identify ctx.g

let rec func_to_spec (ctx: context) {params; locals; result; body} =
  let open Wasm in
  let f =
    { ftype = func_to_spec_type ctx ~params ~result
    ; locals
    ; body = List.map (instr_to_spec ctx) body
    } @@ no_region
  in
  let id = Index.id ctx.f f in
  Int32.of_int id @@ no_region

and instr_to_spec (ctx: context) (instr: instr) =
  let open Wasm in
  instr ctx @@ no_region

let module_to_spec (m: module_) =
  let open Wasm in
  let ctx =
    { f = Index.create ()
    ; g = Index.create ()
    ; m = Index.create ()
    ; ty = Index.create ()
    ; tab = Index.create ()
    }
  in
  let f_exports = List.map (fun (name, fn) ->
      let f = func_to_spec ctx fn in
      { name = Utf8.decode name
      ; edesc = FuncExport f @@ no_region
      } @@ no_region
    ) m.funcs
  and g_exports = List.map (fun (name, g) ->
      let g = global_to_spec ctx g in
      { name = Utf8.decode name
      ; edesc = GlobalExport g @@ no_region
      } @@ no_region
    ) m.globals
  and m_exports =
    List.map (fun (name, m) ->
        let m = memory_to_spec ctx m in
        { name = Utf8.decode name
        ; edesc = MemoryExport m @@ no_region
        } @@ no_region
    ) m.memories
  and data =
    (* TODO: this should grow the memory's minimum size *)
    List.map (fun (m, offset, init) ->
        { index = memory_to_spec ctx m
        ; offset = [ Const ( I32 (Int32.of_int offset) @@ no_region) @@ no_region ] @@ no_region
        ; init
        } @@ no_region
      ) m.data
  and elems =
    (* TODO: this should grow the table's minimum size *)
    List.map (fun (t, offset, f) ->
        { index = table_to_spec ctx t
        ; offset = [ Const ( I32 (Int32.of_int offset) @@ no_region) @@ no_region ] @@ no_region
        ; init = [ func_to_spec ctx f ]
        } @@ no_region
      ) m.elems
  in
  let globals =
    Array.map (fun g ->
        { gtype = GlobalType (g.type_, if g.mutable_ then Mutable else Immutable)
        ; value = List.map (instr_to_spec ctx) g.init @@ no_region
        } @@ no_region
      ) (Index.elements ctx.g)
    |> Array.to_list
  and memories =
    Array.map (fun m ->
        { mtype = MemoryType { min = Int32.of_int m.m_min_size
                             ; max= Option.map Int32.of_int m.m_max_size
                             }
        } @@ no_region
      ) (Index.elements ctx.m)
    |> Array.to_list
  and tables =
    Array.map (fun t ->
        { ttype = TableType ({ min = Int32.of_int t.t_min_size
                             ; max= Option.map Int32.of_int t.t_max_size
                             }, FuncRefType)
        } @@ no_region
      ) (Index.elements ctx.tab)
    |> Array.to_list
  in
  { start = Option.map (func_to_spec ctx) m.start
  ; exports = m_exports @ g_exports @ f_exports
  ; types = Array.to_list (Index.elements ctx.ty)
  ; funcs = Array.to_list (Index.elements ctx.f)
  ; globals
  ; tables
  ; elems
  ; memories
  ; data
  ; imports = []
  } @@ no_region

module Intructions = struct
  open Wasm

  let nop _ = Nop
  let i32_const x _ = Const (I32 x @@ no_region)
  let i32_const' x = i32_const (Int32.of_int x)
  let local_get i _ = LocalGet (Int32.of_int i @@ no_region)
  let local_set i _ = LocalSet (Int32.of_int i @@ no_region)
  let local_tee i _ = LocalTee (Int32.of_int i @@ no_region)
  let global_get x ctx = GlobalGet (global_to_spec ctx x)
  let global_set x ctx = GlobalSet (global_to_spec ctx x)
  let call x ctx = Call (func_to_spec ctx x)
  let call_indirect x ctx = CallIndirect (table_to_spec ctx x)

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

  let load ?offset m type_ ctx =
    let offset = Int32.of_int (Option.value ~default:0 offset) in
    let _id = memory_to_spec ctx m in
    Load {ty = type_; align=2; offset; sz=None}

  let i32_ge_u _ = Compare (I32 I32Op.GeU)
  let i32_gt_u _ = Compare (I32 I32Op.GtU)
  let i32_le_u _ = Compare (I32 I32Op.LeU)
  let i32_lt_u _ = Compare (I32 I32Op.LtU)

  let if_ ?(params=[]) ?(result=[]) then_ else_ ctx =
    let t = func_to_spec_type ctx ~params ~result in
    If (VarBlockType t, List.map (instr_to_spec ctx) then_, List.map (instr_to_spec ctx) else_)
end
include Intructions
