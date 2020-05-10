(module
  ;; The contract module imports linear memory from javascript
  (import "memory" "object" (memory 1))

  ;; Allocation
  ;; A global variable serves as allocation pointer. Both sides will increment
  ;; it during allocation.
  (global $alloc (import "memory" "alloc_p") (mut i32))

  ;; allocate one word, store i32 argument, return address
  (func $store_int32 (param i32) (result i32)
        global.get $alloc ;; return
        global.get $alloc ;; store
        global.get $alloc ;; allocation
        i32.const 4
        i32.add
        global.set $alloc ;; end allocation
        get_local 0
        i32.store ;; end store
        )

  ;; Initialization
  ;;
  ;; type init = unit -> state
  ;; wasm: func (result i32)
  ;;
  ;; The initialization function take no arguments and returns an integer.
  ;; The return value points to the initial state.

  ;; Example: counter contract with type state = int and initial value 42
  (func (export "init") (result i32)
        i32.const 42
        call $store_int32
        )

  ;; Clauses
  ;;
  ;; type clause = state -> payload -> response
  ;; wasm: func (param $state i32) (param $payload i32) (result i32)
  ;;
  ;; A clause takes two integer parameters and returns an integer.
  ;; The first argument points to the input state.
  ;; The second argument points to the payload.
  ;; The return value points to the response.

  ;; We set type response = state for now.

  ;; incr clause. type payload = unit
  (func (export "incr") (param $state i32) (param $payload i32) (result i32)
        get_local $state
        i32.load ;; load state from memory
        i32.const 1
        i32.add
        call $store_int32
        )

  ;; decr clause. type payload = unit
  (func (export "decr") (param $state i32) (param $payload i32) (result i32)
        get_local $state
        i32.load ;; load state from memory
        i32.const 1
        i32.sub
        call $store_int32
        )
  )
