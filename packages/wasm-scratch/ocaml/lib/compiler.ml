open Ergo_lib

type context =
  { mutable constants : string list
  ; mutable constants_size : int
  ; alloc_p : Ir.global
  }

let create_context () = { constants = []
                        ; constants_size = 0
                        ; alloc_p = Ir.(global ~mutable_:true i32 [i32_const' 0])
                        }

exception Unsupported of string
let unsupported : type a. string -> a = fun s -> raise (Unsupported s)

type data = Core.ejson
type op = Core.ejson_op
type runtime = Core.ejson_runtime_op

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
  let offset = ctx.constants_size in
  ctx.constants <- s :: ctx.constants;
  ctx.constants_size <- String.length s + ctx.constants_size;
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
  | ImpExprVar varname -> unsupported "expr: var"
  | ImpExprConst x -> [const ctx x]
  | ImpExprOp (x, args) -> op ctx x (List.map (expr ctx) args)
  | ImpExprRuntimeCall (op, args) -> unsupported "expr: runtime call"

let f_start ctx =
  let open Ir in
  func [ i32_const' ctx.constants_size; global_set ctx.alloc_p ]

let module_ ctx funcs : Ir.module_ =
  { Ir.start = Some (f_start ctx)
  ; globals = ["alloc_p", ctx.alloc_p]
  ; memory = Some "memory"
  ; funcs
  ; data = [ 0, String.concat "" (List.rev ctx.constants) ]
  }
