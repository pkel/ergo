open Import

type module_context =
  { constants: string Table.t
  ; alloc_p : Ir.global
  ; memory : Ir.memory
  }

type function_context =
  { locals : char list Table.t
  ; lib : Ir_lib.t
  }

let create_context () = { constants = Table.create ~element_size:String.length
                        ; alloc_p = Ir.(global ~mutable_:true i32 [i32_const' 0])
                        ; memory = Ir.(memory 1)
                        }

let op (module L : Ir_lib.LIB) op : Ir.instr list =
  match (op : op) with
  | EJsonOpNot -> [Ir.call L.not]
  | EJsonOpNeg -> unsupported "op: neg"
  | EJsonOpAnd -> [Ir.call L.and_]
  | EJsonOpOr -> [Ir.call L.or_]
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
  let module L = (val ctx.lib) in
  match (expression : _ Core.imp_expr) with
  | ImpExprError err -> unsupported "expr: error"
  | ImpExprVar v -> [Ir.local_get (Table.offset ctx.locals v)]
  | ImpExprConst x -> [L.const x]
  | ImpExprOp (x, args) ->
    (* Put arguments on the stack, append operator *)
    (List.map (expr ctx) args |> List.concat) @ (op ctx.lib x)
  | ImpExprRuntimeCall (op, args) -> unsupported "expr: runtime call"

let rec statement ctx stmt : Ir.instr list =
  match (stmt : _ Core.imp_stmt) with
  | ImpStmtBlock (vars, stmts) ->
    (* TODO: This assumes that variable names are unique which is not true in general. *)
    let defs =
      List.map (fun (var, value) ->
          let id = Table.offset ctx.locals var in
          match value with
          | Some x ->  expr ctx x @ [ Ir.local_set id ]
          | None -> []
        ) vars
    in
    let body = List.map (statement ctx) stmts in
    List.concat (defs @ body)
  | ImpStmtAssign (var, x) ->
    expr ctx x @ [ Ir.local_set (Table.offset ctx.locals var) ]
  | ImpStmtFor _ -> unsupported "statement: for"
  | ImpStmtForRange _ -> unsupported "statement: for range"
  | ImpStmtIf _ -> unsupported "statement: if"

let function_ {memory; alloc_p; constants} fn : Ir.func =
  let lib = Ir_lib.make ~memory ~alloc_p ~constants in
  let Core.ImpFun (arg, stmt, ret) = fn in
  let locals = Table.create ~element_size:(fun _ -> 1) in
  let ctx = {locals; lib } in
  let l_arg = Table.offset locals arg in
  let () = assert (l_arg = 0) in
  let body =
    statement ctx stmt @
    Ir.[ local_get (Table.offset locals ret) ]
  in
  let locals = List.init (Table.size locals - 1) (fun _ -> Ir.i32) in
  Ir.(func ~params:[i32] ~result:[i32] ~locals body)

let f_start ctx =
  let size = Table.size ctx.constants in
  let open Ir in
  func [ i32_const' size; global_set ctx.alloc_p ]

let imp functions : Wasm.Ast.module_ =
  let ctx = create_context () in
  let funcs = List.map (fun (name, fn) ->
      (Util.string_of_char_list name, function_ ctx fn)) functions
  and f_start = f_start ctx
  in
  let data =
    List.fold_left (fun acc (_, el) -> acc ^ el) "" (Table.elements ctx.constants)
  in
  Ir.module_to_spec
    { Ir.start = Some (f_start)
    ; globals = ["alloc_p", ctx.alloc_p]
    ; memories = ["memory", ctx.memory]
    ; tables = []
    ; funcs
    ; data = [ ctx.memory, 0, data ]
    ; elems = []
    }
