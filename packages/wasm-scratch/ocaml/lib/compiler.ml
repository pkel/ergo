module Index : sig
  type 'a t

  val create : unit -> 'a t
  val id : 'a t -> 'a -> int
  val elements : 'a t -> 'a array
  val size : 'a t -> int
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

  let size (_, size) = !size
end

open Ergo_lib

type data = Core.ejson
type op = Core.ejson_op
type runtime = Core.ejson_runtime_op
type imp = Core.imp_ejson

exception Unsupported of string
let unsupported : type a. string -> a = fun s -> raise (Unsupported s)

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

module Constants : sig
  type t

  val create : unit -> t
  val offset : t -> data -> int
  val data : t -> string
  val size : t -> int
end = struct
  type t = (data, int) Hashtbl.t * string ref * int ref

  let create () = Hashtbl.create 7, ref "", ref 0

  let offset (ht, data, size) x =
    match Hashtbl.find_opt ht x with
    | Some offset -> offset
    | None ->
      let offset = !size in
      let el = Bytes.to_string (encode x) in
      size := String.length el + !size;
      data := !data ^ (Bytes.to_string (encode x));
      Hashtbl.add ht x offset;
      offset

  let data (_, data, _) = !data
  let size (_, _, size) = !size
end

type module_context =
  { constants: Constants.t
  ; alloc_p : Ir.global
  ; memory : Ir.memory
  }

type function_ctx =
  { locals : char list Index.t
  ; global : module_context
  }

let create_context () = { constants = Constants.create ()
                        ; alloc_p = Ir.(global ~mutable_:true i32 [i32_const' 0])
                        ; memory = Ir.(memory 1)
                        }

let const ctx x : Ir.instr =
  let offset = Constants.offset ctx.global.constants x in
  Ir.i32_const' offset

let c_true ctx = const ctx (Ejbool true)
let c_false ctx = const ctx (Ejbool false)

(* null and false are "falsy".
 * null has tag 0. false has tag 1. *)
let f_not ctx =
  let open Ir in
  func ~params:[i32] ~result:[i32]
    [ local_get 0
    ; load ctx.global.memory i32
    ; i32_const' 1
    ; i32_le_u
    ; if_ ~result:[i32]
        [ c_true ctx ]
        [ c_false ctx ]
    ]

let f_bitwise_binary ctx cmp =
  let open Ir in
  func ~params:[i32; i32] ~result:[i32]
    [ local_get 0
    ; load ctx.global.memory i32
    ; i32_const' 1
    ; i32_le_u
    ; local_get 1
    ; load ctx.global.memory i32
    ; i32_const' 1
    ; i32_le_u
    ; cmp
    ; if_ ~result:[i32]
        [ c_true ctx ]
        [ c_false ctx ]
    ]

let f_and ctx = f_bitwise_binary ctx Ir.i32_and
let f_or ctx = f_bitwise_binary ctx Ir.i32_or

let op ctx op : Ir.instr list =
  let open Ir in
  match (op : op) with
  | EJsonOpNot -> [call (f_not ctx)]
  | EJsonOpNeg -> unsupported "op: neg"
  | EJsonOpAnd -> [call (f_and ctx)]
  | EJsonOpOr -> [call (f_or ctx)]
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
  | ImpExprOp (x, args) ->
    (* Put arguments on the stack, append operator *)
    (List.map (expr ctx) args |> List.concat) @ (op ctx x)
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
  let locals = List.init (Index.size locals - 1) (fun _ -> Ir.i32) in
  Ir.(func ~params:[i32] ~result:[i32] ~locals body)

let f_start ctx =
  let size = Constants.size ctx.constants in
  let open Ir in
  func [ i32_const' size; global_set ctx.alloc_p ]

let imp functions : Wasm.Ast.module_ =
  let ctx = create_context () in
  let funcs = List.map (fun (name, fn) ->
      (Util.string_of_char_list name, function_ ctx fn)) functions
  in
  Ir.module_to_spec
    { Ir.start = Some (f_start ctx)
    ; globals = ["alloc_p", ctx.alloc_p]
    ; memories = ["memory", ctx.memory]
    ; funcs
    ; data = [ ctx.memory, 0, Constants.data ctx.constants ]
    }
