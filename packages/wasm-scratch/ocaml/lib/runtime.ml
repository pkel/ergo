open Wasm.Types
open Wasm.Values
open Wasm.Ast
open Wasm.Source

class module_ = object(self)
  val mutable types : type_ list = []
  val mutable funcs : func list = []
  val mutable tab : table_segment list = []
  val mutable tab_size : int = 0

  method type_ ( x : func_type ) : var =
    let i = List.length types in
    let () = types <- (x @@ no_region) :: types in
    Int32.of_int i @@ no_region

  method func ?(params=[]) ?(return=[]) ?(locals=[]) body : var =
    let i = List.length funcs
    and f =
      { ftype = self#type_ (FuncType (params, return))
      ; locals
      ; body = List.map (fun x -> x @@ no_region) body
      } @@ no_region
    in
    let () = funcs <- f :: funcs in
    Int32.of_int i @@ no_region

  method return =
    let funcs = List.rev funcs
    and types = List.rev types
    and tables, elems =
      if tab_size <= 0 then [], [] else
        let def =
          { ttype = TableType ( { min= Int32.zero
                                ; max=Some (Int32.of_int (tab_size - 1))
                                }
                              , AnyFuncType
                              )
          }
        and entries = List.rev tab
        in
        [def @@ no_region], entries
    in { empty_module with funcs; types; tables; elems} @@ no_region

  method tabulate a =
    let segment =
      { index = Int32.zero @@ no_region (* there is only one table *)
      ; offset = [ Const (I32 (Int32.of_int tab_size) @@ no_region)
                   @@ no_region
                 ] @@ no_region
      ; init = Array.to_list a
      } @@ no_region
    in
    tab_size <- tab_size + Array.length a;
    tab <- segment :: tab
end

let var i : var = Int32.of_int i @@ no_region

let module_ =
  let m = new module_ in
  let _id0 =
    m#func [ Nop ]
  in
  let _id1 =
    let a = var 0 in
    m#func ~params:[I32Type] ~return:[I32Type]
    [ GetLocal a
    ; Call _id0
    ]
  in
  let _eq_i32 =
    let a, b = var 0, var 1 in
    m#func ~params:[I32Type; I32Type] ~return:[I32Type]
    [ GetLocal a
    ; GetLocal b
    ; Call _id1
    ; Compare (I32 I32Op.Eq)
    ] in
  m#tabulate [|_id1; _eq_i32|];
  m#tabulate [|_id0; _eq_i32|];
  m#return
