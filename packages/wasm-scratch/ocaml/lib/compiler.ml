module Owasm = struct
  include Wasm
  include Types
  include Values
  include Ast
  include Source
end

module Wasm_module = struct
  open Owasm

  type table_alloc = TabSegment of {offset: int; size:int}

  class t = object(self)
    val mutable types : (int * type_) list = []
    val mutable funcs : func list = []

    val mutable tab : table_segment list = []
    val mutable tab_size : int = 0
    val mutable data : string list = []
    val mutable data_size : int = 0
    val mutable exports : export list = []

    method func_type ~param ~result : var =
      let el = (FuncType (param, result) @@ no_region) in
      let i =
        match List.find_opt (fun (_, el') -> el = el') types with
        | Some (id, _) -> id
        | None ->
          let id = List.length types in
          let () = types <- (id, el) :: types in
          id
      in
      Int32.of_int i @@ no_region

    method func ?(param=[]) ?(result=[]) ?(local=[]) body : var =
      let i = List.length funcs
      and f =
        { ftype = self#func_type ~param ~result
        ; locals = local
        ; body = List.map (fun x -> x @@ no_region) body
        } @@ no_region
      in
      let () = funcs <- f :: funcs in
      Int32.of_int i @@ no_region

    method return =
      let funcs = List.rev funcs
      and types = List.rev_map snd types
      and memories =
        [ {mtype= MemoryType {min= Int32.one; max = None} } @@ no_region ]
      and globals =
        [ { gtype = GlobalType (I32Type, Mutable)
          ; value = [ Const (I32 (Int32.of_int data_size) @@ no_region) @@no_region ] @@ no_region
          } @@ no_region (* global 1, constants offset *)
        ]
      and tables, elems =
        if tab_size <= 0 then [], [] else
          let def =
            { ttype = TableType ( { min= Int32.of_int tab_size
                                  ; max= None
                                  }
                                , FuncRefType
                                )
            }
          and entries = List.rev tab
          in
          [def @@ no_region], entries
      and data =
        [ { index = Int32.zero @@ no_region (* there is only one memory *)
          ; offset = [ Const ( I32 (Int32.of_int 0) @@ no_region) @@ no_region
                     ] @@ no_region
          ; init = String.concat "" (List.rev data)
          } @@ no_region
        ]
      and exports =
        [ { name= Utf8.decode "memory"
          ; edesc= MemoryExport (Int32.zero @@ no_region) @@ no_region
          } @@ no_region
        ; { name= Utf8.decode "alloc_p"
          ; edesc= GlobalExport (Int32.zero @@ no_region) @@ no_region
          } @@ no_region
        ] @ List.rev exports
      in { start= None
         ; globals
         ; memories
         ; funcs
         ; types
         ; tables
         ; elems
         ; data
         ; exports
         ; imports = []
         } @@ no_region

    method table_alloc size =
      let offset = tab_size in
      tab_size <- tab_size + size;
      TabSegment {offset; size}

    method elems (TabSegment {offset; size}) l =
      if List.length l <> size then failwith "table segment size mismatch";
      let segment =
        { index = Int32.zero @@ no_region (* there is only one table *)
        ; offset = [ Const (I32 (Int32.of_int offset) @@ no_region)
                     @@ no_region
                   ] @@ no_region
        ; init = l
        } @@ no_region
      in
      tab <- segment :: tab

    method data x =
      let s = Bytes.to_string x in
      let offset = data_size in
      data <- s :: data;
      data_size <- String.length s + data_size;
      Int32.of_int offset

    method export name f =
      let export =
        { name = Utf8.decode name
        ; edesc = (FuncExport f @@ no_region)
        } @@ no_region
      in
      exports <- export :: exports
  end
end

exception Unsupported of string
let unsupported : type a. string -> a = fun s -> raise (Unsupported s)

open Ergo_lib

type data = Core.ejson
type op = Core.ejson_op
type runtime = Core.ejson_runtime_op

let const : data -> bytes = function
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

let const x (m: Wasm_module.t) : Owasm.instr' list =
  let open Owasm in
  [ Const (I32 (m#data (const x)) @@ no_region) ]

let expr : (data, op, runtime) Core.imp_expr -> Wasm_module.t -> Owasm.instr' list =
  function
  | ImpExprError err -> unsupported "expr: error"
  | ImpExprVar varname -> unsupported "expr: var"
  | ImpExprConst x -> const x
  | ImpExprOp (op, args) -> unsupported "expr: op"
  | ImpExprRuntimeCall (op, args) -> unsupported "expr: runtime call"
