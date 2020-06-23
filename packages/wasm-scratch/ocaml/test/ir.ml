open Ergo_wasm.Ir

let memory = memory 1

let f_nop = func [nop]

let f_nop = func [call f_nop]

let g_alloc_p = global ~mutable_:true i32 [i32_const' 0]

let f_add_i32 = func ~params:[i32; i32] ~result:[i32]
    [ local_get 0
    ; local_get 1
    ; add i32
    ]

let m =
  { start = Some f_nop
  ; funcs = ["add_i32", f_add_i32]
  ; globals = ["alloc_p", g_alloc_p]
  ; memories = ["memory", memory]
  ; data = [memory, 0, "hello world"]
  ; tables = []
  ; elems = []
  }

let () =
  Wasm.Print.module_ stdout 72 (module_to_spec m)
