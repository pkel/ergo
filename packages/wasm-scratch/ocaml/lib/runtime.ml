open Wasm.Types
open Wasm.Values
open Wasm.Ast
open Wasm.Source

type table_alloc = TabSegment of {offset: int; size:int}

class module_ = object(self)
  val mutable types : (int * type_) list = []
  val mutable funcs : func list = []
  val mutable tab : table_segment list = []
  val mutable tab_size : int = 0

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
    and tables, elems =
      if tab_size <= 0 then [], [] else
        let def =
          { ttype = TableType ( { min= Int32.zero
                                ; max=Some (Int32.of_int (tab_size - 1))
                                }
                              , FuncRefType
                              )
          }
        and entries = List.rev tab
        in
        [def @@ no_region], entries
    and memories =
      [{mtype = MemoryType { min= Int32.one; max = None}} @@ no_region]
    in { empty_module with funcs; types; tables; elems; memories} @@ no_region

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
end

let m = new module_

let phrase x = x @@ no_region
let var i : var = Int32.of_int i @@ no_region
let i32_const i : instr' = Const (I32 (Int32.of_int i) @@ no_region)
let tab_offset (TabSegment {offset; _}) = i32_const offset

let block ?(param=[]) ?(result=[]) body : instr' =
  let t = m#func_type ~param ~result in
  Block (VarBlockType t, List.map phrase body)

let loop ?(param=[]) ?(result=[]) body : instr' =
  let t = m#func_type ~param ~result in
  Loop (VarBlockType t, List.map phrase body)

let if_ ?(param=[]) ?(result=[]) then_ else_ : instr' =
  let t = m#func_type ~param ~result in
  If (VarBlockType t, List.map phrase then_, List.map phrase else_)

let load ?sz ?align ?(offset=0) ty : instr' =
  (* TODO: understand what align is doing. The below seems to be the defaults
   * in wasm text format. *)
  let align = match align with
    | Some x -> x
    | None -> match sz with
      | None -> 2
      | Some (Pack8, _) -> 0
      | Some (Pack16, _) -> 1
      | Some (Pack32, _) -> 2
  in
  Load ({ty; align; sz; offset= Int32.of_int offset})

(* compare two unsigned i32 in memory *)
let cmp_i32u =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type]
    [ LocalGet (var 0)
    ; load I32Type
    ; LocalGet (var 1)
    ; load I32Type
    ; Compare (I32 I32Op.LtU)
    ; if_ ~result:[I32Type] [i32_const (-1)]
        [ LocalGet (var 0)
        ; load I32Type
        ; LocalGet (var 1)
        ; load I32Type
        ; Compare (I32 I32Op.GtU)
        ]
    ]

(* compare table *)
let cmp_tab = m#table_alloc 9

(* compare two values in memory *)
let cmp =
  let ty = m#func_type ~param:[I32Type; I32Type] ~result:[I32Type] in
  m#func ~param:[I32Type; I32Type] ~local:[I32Type] ~result:[I32Type]
    [ LocalGet (var 0)
    ; LocalGet (var 1)
    ; Call cmp_i32u
    ; LocalTee (var 2) (* store tag comparison result into local variable *)
    ; i32_const 0
    ; Compare (I32 I32Op.Eq)
    ; if_ ~result:[I32Type]
        [ LocalGet (var 0)
        ; load ~offset:4 I32Type
        ; LocalGet (var 1)
        ; load ~offset:4 I32Type
        ; LocalGet (var 0)
        ; load I32Type
        ; tab_offset cmp_tab
        ; Binary (I32 I32Op.Add)
        ; CallIndirect ty
        ]
        [ LocalGet (var 2) ]
    ]

(* tag || nothing : tag was compared before, thus values are equal. *)
let cmp_unit =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type]
    [ i32_const 0 ]

(* tag || int : load integers from memory, compare *)
let cmp_i32s =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type]
    [ LocalGet (var 0)
    ; load I32Type
    ; LocalGet (var 1)
    ; load I32Type
    ; Compare (I32 I32Op.LtS)
    ; if_ ~result:[I32Type] [i32_const (-1)]
        [ LocalGet (var 0)
        ; load I32Type
        ; LocalGet (var 1)
        ; load I32Type
        ; Compare (I32 I32Op.GtS)
        ]
    ]

(* tag || float : load floats from memory, compare *)
let cmp_f32 =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type]
    [ LocalGet (var 0)
    ; load F32Type
    ; LocalGet (var 1)
    ; load F32Type
    ; Compare (F32 F32Op.Lt)
    ; if_ ~result:[I32Type] [i32_const (-1)]
        [ LocalGet (var 0)
        ; load F32Type
        ; LocalGet (var 1)
        ; load F32Type
        ; Compare (F32 F32Op.Gt)
        ]
    ]

(* tag || pointer : recurse on pointer *)
let cmp_rec1 =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type]
    [ LocalGet (var 0)
    ; load I32Type
    ; LocalGet (var 1)
    ; load I32Type
    ; Call cmp
    ]

(* tag || pointer pointer : recurse on pointers *)
let cmp_rec2 =
  m#func ~param:[I32Type; I32Type] ~result:[I32Type] ~local:[I32Type]
    [ LocalGet (var 0)
    ; load I32Type
    ; LocalGet (var 1)
    ; load I32Type
    ; Call cmp
    ; LocalTee (var 2)
    ; i32_const 0
    ; Compare (I32 I32Op.Eq)
    ; if_ ~result:[I32Type]
        [ LocalGet (var 0)
        ; load ~offset:4 I32Type
        ; LocalGet (var 1)
        ; load ~offset:4 I32Type
        ; Call cmp
        ]
        [ LocalGet (var 2) ]
    ]

(* tag || i32 byte byte .. : loop over bytes *)
let cmp_string =
  let a, b, result, end_ = var 0, var 1, var 2, var 3 in
  m#func ~param:[I32Type; I32Type] ~result:[I32Type] ~local:[I32Type; I32Type]
    [ LocalGet a
    ; LocalGet b
    ; Call cmp_i32u
    ; LocalTee result
    ; i32_const 0
    ; Compare (I32 I32Op.Eq)
    ; if_ ~result:[I32Type]
        (* lengths equal *)
        [ (* put length on the stack *)
          LocalGet a
        ; load I32Type
        ; (* initiate moving pointer in a *)
          LocalGet a
        ; i32_const 3
        ; Binary (I32 I32Op.Add)
        ; LocalTee a
        ; (* set end address: start + length; length is on the stack *)
          Binary (I32 I32Op.Add)
        ; LocalSet end_
        ; (* initiate moving pointer in b *)
          LocalGet b
        ; i32_const 3
        ; Binary (I32 I32Op.Add)
        ; LocalSet b
        ; loop ~result:[I32Type]
          [ (* check end of string *)
            LocalGet a
          ; LocalGet end_
          ; Compare (I32 I32Op.GeU)
          ; if_ ~result:[I32Type]
              (* end of string reached. Strings are equal. *)
              [ i32_const 0 ]
              (* compare next character *)
              [ (* load ++a *)
                LocalGet a
              ; i32_const 1
              ; Binary (I32 I32Op.Add)
              ; LocalTee a
              ; load ~sz:(Pack8, ZX) I32Type
              ; (* load ++b *)
                LocalGet b
              ; i32_const 1
              ; Binary (I32 I32Op.Add)
              ; LocalTee b
              ; load ~sz:(Pack8, ZX) I32Type
              ; Call cmp_i32u
              ; LocalTee result
              ; i32_const 0
              ; Compare (I32 I32Op.Eq)
              ; (* if equal: leave if-block, jump to beginning of loop-block *)
                BrIf (var 1)
              ; (* if not equal: leave comparison result on stack, exit loop *)
                LocalGet result
              ]
          ]
        ]
        (* unequal lengths *)
        [ LocalGet result ]
    ]

let () =
  m#elems cmp_tab
    [ cmp_unit   (* 0 unit *)
    ; cmp_unit   (* 1 false *)
    ; cmp_unit   (* 2 true *)
    ; cmp_i32s   (* 3 int *)
    ; cmp_f32    (* 4 float *)
    ; cmp_rec1   (* 5 left *)
    ; cmp_rec1   (* 6 right *)
    ; cmp_rec2   (* 7 pair *)
    ; cmp_string (* 8 string *)
    ]

let module_ = m#return
