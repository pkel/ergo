type pos =
  { offset: int
  ; nth : int
  }

type 'a t =
  { ht: ('a, pos) Hashtbl.t
  ; mutable size: int
  ; mutable n: int
  ; element_size: 'a -> int
  }

let create ~element_size =
  { ht = Hashtbl.create 7
  ; size = 0
  ; element_size
  ; n = 0
  }

let offset t el =
  match Hashtbl.find_opt t.ht el with
  | Some pos -> pos.offset
  | None ->
    let offset = t.size in
    Hashtbl.add t.ht el {offset; nth = t.n};
    t.n <- t.n + 1;
    t.size <- t.element_size el + t.size;
    offset

let elements t =
  let a = Array.make t.n None in
  Hashtbl.iter (fun el pos -> a.(pos.nth) <- Some (pos.offset, el)) t.ht;
  Array.map Option.get a
  |> Array.to_list

let size t = t.size
