open Wasm

let () =
  Valid.check_module Ergo_wasm.Runtime.module_;
  Print.module_ stdout 72 Ergo_wasm.Runtime.module_
