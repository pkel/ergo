open Import

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
  | Ejarray _ -> unsupported "ejson encode: array"
  | Ejobject _ -> unsupported "ejson encode: object"
  | Ejforeign _ -> unsupported "ejson encode: foreign"
  | Ejbigint x -> unsupported "ejson encode: bigint"

let write mem alloc_p x =
  let data = encode x |> Bytes.to_string in
  let addr =
    match Wasm.Global.load alloc_p with
    | I32 x -> x
    | _ -> failwith "incompatible module (type of alloc_p)"
  and n =
    String.length data |> Int32.of_int
  in
  let open Wasm.Memory in
  store_bytes mem (Int64.of_int32 addr) data;
  Wasm.Global.store alloc_p (I32 (Int32.add n  addr));
  addr

let read mem addr : data =
  let open Wasm.Values in
  let open Wasm.Types in
  let open Wasm.Memory in
  let i32 addr offset =
    match load_value mem (Int64.of_int32 addr) (Int32.of_int offset) I32Type with
    | I32 x -> x
    | _ -> assert false
  and double addr offset =
    match load_value mem (Int64.of_int32 addr) (Int32.of_int offset) I64Type with
    | I64 x -> Int64.float_of_bits x
    | _ -> assert false
  in
  let rec r addr : data =
    match Int32.to_int (i32 addr 0) with
    | 0 -> Ejnull
    | 1 -> Ejbool false
    | 2 -> Ejbool true
    | 3 -> Ejnumber (double addr 4)
    | 4 ->
      let n = i32 addr 4 |> Int32.to_int in
      let addr = Int32.add addr (Int32.of_int 8) |> Int64.of_int32 in
      Ejstring (load_bytes mem addr n |> Util.char_list_of_string)
    | _ -> unsupported "ejson read"
  in
  r addr
