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

type compile_ctx =
  { f : Wasm.Ast.func Index.t
  ; g : Wasm.Ast.global Index.t
  ; t : Wasm.Ast.type_ Index.t
  }

type type_ = Wasm.Types.value_type

let i32 = Wasm.Types.I32Type
let i64 = Wasm.Types.I64Type
let f64 = Wasm.Types.F64Type

type instr = compile_ctx -> Wasm.Ast.instr'

type func =
  { params : type_ list
  ; result : type_ list
  ; locals : type_ list
  ; body : instr list
  }

let func ?(params=[]) ?(result=[]) ?(locals=[]) body =
  { params; locals; result; body}

type global =
  { id: int
  ; mutable_: bool
  ; type_: type_
  ; init: instr list
  }

let global =
  let cnt = ref 0 in
  fun ~mutable_ type_ init ->
    let g = { id = !cnt; mutable_; type_; init } in
    incr cnt; g

type module_ =
  { start: func option
  ; funcs: (string * func) list
  ; globals: (string * global) list
  ; memory: string option
  ; data : (int * string) list
  }

module Wasm = struct
  include Wasm
  include Types
  include Values
  include Ast
  include Source
end

let compile_func_type (ctx: compile_ctx) ~params ~result =
  let open Wasm in
  let t = FuncType (params, result) @@ no_region in
  let id = Index.id ctx.t t in
  Int32.of_int id @@ no_region

let rec compile_global (ctx: compile_ctx) (g: global) =
  let open Wasm in
  let g =
    { gtype = GlobalType (g.type_, if g.mutable_ then Mutable else Immutable)
    ; value = List.map (compile_instr ctx) g.init @@ no_region
    } @@ no_region (* global 1, constants offset *)
  in
  let id = Index.id ctx.g g in
  Int32.of_int id @@ no_region

and compile_func (ctx: compile_ctx) {params; locals; result; body} =
  let open Wasm in
  let f =
    { ftype = compile_func_type ctx ~params ~result
    ; locals
    ; body = List.map (compile_instr ctx) body
    } @@ no_region
  in
  let id = Index.id ctx.f f in
  Int32.of_int id @@ no_region

and compile_instr (ctx: compile_ctx) (instr: instr) =
  let open Wasm in
  instr ctx @@ no_region

let compile (m: module_) =
  let open Wasm in
  let ctx =
    { f = Index.create ()
    ; g = Index.create ()
    ; t = Index.create ()
    }
  in
  let f_exports = List.map (fun (name, fn) ->
      let f = compile_func ctx fn in
      { name = Utf8.decode name
      ; edesc = FuncExport f @@ no_region
      } @@ no_region
    ) m.funcs
  and g_exports = List.map (fun (name, g) ->
      let g = compile_global ctx g in
      { name = Utf8.decode name
      ; edesc = GlobalExport g @@ no_region
      } @@ no_region
    ) m.globals
  and m_exports =
    match m.memory with
    | None -> []
    | Some s ->
      [ { name = Utf8.decode s
        ; edesc = MemoryExport (Int32.zero @@ no_region) @@ no_region
        } @@ no_region
      ]
  and data =
    List.map (fun (offset, init) ->
        { index = Int32.zero @@ no_region
        ; offset = [ Const ( I32 (Int32.of_int offset) @@ no_region) @@ no_region ] @@ no_region
        ; init
        } @@ no_region
      ) m.data
  in
  { start = Option.map (compile_func ctx) m.start
  ; exports = m_exports @ g_exports @ f_exports
  ; types = Array.to_list (Index.elements ctx.t)
  ; funcs = Array.to_list (Index.elements ctx.f)
  ; globals = Array.to_list (Index.elements ctx.g)
  ; tables = []
  ; elems = []
  ; memories =
      (* TODO: make this flexible & allow import / export *)
      [ {mtype= MemoryType {min= Int32.one; max = None} } @@ no_region ]
  ; data
  ; imports = []
  } @@ no_region

module Intructions = struct
  open Wasm

  let nop _ = Nop
  let i32_const x _ = Const (I32 x @@ no_region)
  let i32_const' x = i32_const (Int32.of_int x)
  let i32_add _ = Binary (I32 I32Op.Add)
  let local_get i _ = LocalGet (Int32.of_int i @@ no_region)
  let local_set i _ = LocalSet (Int32.of_int i @@ no_region)
  let local_tee i _ = LocalTee (Int32.of_int i @@ no_region)
  let global_get x ctx = GlobalGet (compile_global ctx x)
  let global_set x ctx = GlobalSet (compile_global ctx x)
  let call x ctx = Call (compile_func ctx x)
end
include Intructions
