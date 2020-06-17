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

open Ergo_lib

type global_context =
  { mutable constants : string list
  ; mutable constants_size : int
  ; alloc_p : Ir.global
  ; memory : Ir.memory
  }

type local_ctx =
  { locals : char list Index.t
  ; global : global_context
  }

let create_context () = { constants = []
                        ; constants_size = 0
                        ; alloc_p = Ir.(global ~mutable_:true i32 [i32_const' 0])
                        ; memory = Ir.(memory 1)
                        }

exception Unsupported of string
let unsupported : type a. string -> a = fun s -> raise (Unsupported s)

type data = Core.ejson
type op = Core.ejson_op
type runtime = Core.ejson_runtime_op
type imp = Core.imp_ejson

let encode : data -> bytes = function
  | Ejnull ->
    let b = Bytes.create 4 in
    Bytes.set_int32_le b 0 (Int32.of_int 0);
    b
  | Ejbool false ->
    let b = Bytes.create 4 in
    Bytes.set_int32_le b 0 (Int32.of_int 1);
    b
  | Ejbool true ->
    let b = Bytes.create 4 in
    Bytes.set_int32_le b 0 (Int32.of_int 2);
    b
  | Ejnumber x ->
    let b = Bytes.create 12 in
    Bytes.set_int32_le b 0 (Int32.of_int 3);
    Bytes.set_int64_le b 4 (Int64.bits_of_float x);
    b
  | Ejstring s ->
    let n = List.length s in
    let b = Bytes.create (8 + n) in
    Bytes.set_int32_le b 0 (Int32.of_int 4);
    Bytes.set_int32_le b 4 (Int32.of_int n);
    List.iteri (fun i c -> Bytes.set b (8 + i) c) s;
    b
  | Ejarray _ -> unsupported "const: array"
  | Ejobject _ -> unsupported "const: object"
  | Ejforeign _ -> unsupported "const: foreign"
  | Ejbigint x -> unsupported "const: bigint"

let const ctx x : Ir.instr =
  let s = Bytes.to_string (encode x) in
  let offset = ctx.global.constants_size in
  ctx.global.constants <- s :: ctx.global.constants;
  ctx.global.constants_size <- String.length s + ctx.global.constants_size;
  Ir.i32_const' offset

let f_not =
  (* TODO: implement this operator correctly *)
  let open Ir in
  func ~params:[i32] ~result:[i32] [ nop ]

let op ctx op args : Ir.instr list =
  let open Ir in
  match (op : op) with
  | EJsonOpNot -> List.concat (args @ [[call f_not]])
  | EJsonOpNeg
  | EJsonOpAnd
  | EJsonOpOr
  | EJsonOpLt
  | EJsonOpLe
  | EJsonOpGt
  | EJsonOpGe
  | EJsonOpAddString
  | EJsonOpAddNumber
  | EJsonOpSub
  | EJsonOpMult
  | EJsonOpDiv
  | EJsonOpStrictEqual
  | EJsonOpStrictDisequal
  | EJsonOpArray
  | EJsonOpArrayLength
  | EJsonOpArrayPush
  | EJsonOpArrayAccess
  | EJsonOpObject _
  | EJsonOpAccess _
  | EJsonOpHasOwnProperty _
  | EJsonOpMathMin
  | EJsonOpMathMax
  | EJsonOpMathMinApply
  | EJsonOpMathMaxApply
  | EJsonOpMathPow
  | EJsonOpMathExp
  | EJsonOpMathAbs
  | EJsonOpMathLog
  | EJsonOpMathLog10
  | EJsonOpMathSqrt
  | EJsonOpMathCeil
  | EJsonOpMathFloor
  | EJsonOpMathTrunc -> unsupported "op"

let rec expr ctx expression : Ir.instr list =
  match (expression : _ Core.imp_expr) with
  | ImpExprError err -> unsupported "expr: error"
  | ImpExprVar v -> [Ir.local_get (Index.id ctx.locals v)]
  | ImpExprConst x -> [const ctx x]
  | ImpExprOp (x, args) -> op ctx x (List.map (expr ctx) args)
  | ImpExprRuntimeCall (op, args) -> unsupported "expr: runtime call"

let rec statement ctx stmt : Ir.instr list =
  match (stmt : _ Core.imp_stmt) with
  | ImpStmtBlock (vars, stmts) ->
    (* TODO: This assumes that variable names are unique which is not true in general. *)
    let defs =
      List.map (fun (var, value) ->
          let id = Index.id ctx.locals var in
          match value with
          | Some x ->  expr ctx x @ [ Ir.local_set id ]
          | None -> []
        ) vars
    in
    let body = List.map (statement ctx) stmts in
    List.concat (defs @ body)
  | ImpStmtAssign (var, x) ->
    expr ctx x @ [ Ir.local_set (Index.id ctx.locals var) ]
  | ImpStmtFor _ -> unsupported "statement: for"
  | ImpStmtForRange _ -> unsupported "statement: for range"
  | ImpStmtIf _ -> unsupported "statement: if"

let function_ ctx fn : Ir.func =
  let Core.ImpFun (arg, stmt, ret) = fn in
  let locals = Index.create () in
  let ctx = { global = ctx; locals } in
  let l_arg = Index.id locals arg in
  let () = assert (l_arg = 0) in
  let body =
    statement ctx stmt @
    Ir.[ local_get (Index.id locals ret) ]
  in
  Ir.(func ~params:[i32] ~result:[i32] body)

let f_start ctx =
  let open Ir in
  func [ i32_const' ctx.constants_size; global_set ctx.alloc_p ]

let imp functions : Wasm.Ast.module_ =
  let ctx = create_context () in
  let funcs = List.map (fun (name, fn) ->
      (Util.string_of_char_list name, function_ ctx fn)) functions
  in
  Ir.compile
    { Ir.start = Some (f_start ctx)
    ; globals = ["alloc_p", ctx.alloc_p]
    ; memories = ["memory", ctx.memory]
    ; funcs
    ; data = [ ctx.memory, 0, String.concat "" (List.rev ctx.constants) ]
    }
