open Ergo_wasm.Ir

let f_nop = func [nop]

let f_nop = func [call f_nop]

let g_alloc_p = global ~mutable_:true i32 [i32_const' 0]

let f_add_i32 = func ~params:[i32; i32] ~result:[i32]
    [ local_get 0
    ; local_get 1
    ; i32_add
    ]

let m =
  { start = Some f_nop
  ; funcs = ["add_i32", f_add_i32]
  ; globals = ["alloc_p", g_alloc_p]
  ; data = [0, "hello world"]
  ; memory = Some "memory"
  }

let () =
  Wasm.Print.module_ stdout 72 (compile m)
