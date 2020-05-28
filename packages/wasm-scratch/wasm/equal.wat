(module
  ;; The contract module imports linear memory from Javascript
  (import "memory" "object" (memory 1))

  ;; Allocation
  ;; A global variable serves as allocation pointer.
  ;; Both sides increment it during allocation.
  (global $alloc (import "memory" "alloc_p") (mut i32))

  ;; allocate one word, store i32 argument, return address
  (func $alloc_i32 (param i32) (result i32)
        global.get $alloc ;; return
        global.get $alloc ;; store
        global.get $alloc ;; allocation
        i32.const 4
        i32.add
        global.set $alloc ;; end allocation
        get_local 0
        i32.store ;; end store
        )

  ;; clause-like wrapper around $equal function.
  ;; argument: pointer to a pair
  ;; result: pointer to a boolean
  (func (export "equal") (param i32) (result i32)
        ;; check argument is pair
        local.get 0
        i32.load
        i32.const 7
        i32.eq
        if (result i32)
          ;; argument is pair, compare the values
          local.get 0
          i32.const 4
          i32.add
          i32.load
          local.get 0
          i32.const 8
          i32.add
          i32.load
          call $equal
        else
          ;; argument is no pair, return false
          i32.const 0
        end
        ;; turn i32 0/1 on stack into boolean false
        ;; false has tag 1
        ;; true has tag 2
        i32.const 1
        i32.add
        call $alloc_i32
        )

  ;; Recursive equality.
  ;; arguments: two pointers
  ;; result: i32 0/1 interpreted as boolean
  (func $equal (param $a i32) (param $b i32) (result i32)
        local.get $a
        local.get $b
        call $eq_int
        if ;; tags equal
          ;; use one of the below equalities
          ;; prepare arg a
          get_local $a
          i32.const 4
          i32.add
          ;; prepare arg b
          get_local $b
          i32.const 4
          i32.add
          ;; load tag
          get_local $a
          i32.load
          ;; jump via table
          (call_indirect (param i32) (param i32) (result i32))
          return
        end ;; tags not equal
        i32.const 0
        )

  (table 32 funcref)
  (elem (i32.const 0)
        $eq_unit   ;; 0 unit
        $eq_unit   ;; 1 false
        $eq_unit   ;; 2 true
        $eq_int    ;; 3 int
        $eq_float  ;; 4 float
        $eq_rec1   ;; 5 left
        $eq_rec1   ;; 6 right
        $eq_rec2   ;; 7 pair
        $eq_string ;; 8 string
        )

  ;; tag || nothing
  (func $eq_unit (param i32) (param i32) (result i32) i32.const 1)

  ;; tag || int
  (func $eq_int (param i32 i32) (result i32)
        get_local 0
        i32.load
        get_local 1
        i32.load
        i32.eq)

  ;; tag || float
  (func $eq_float (param i32 i32) (result i32)
        get_local 0
        f32.load
        get_local 1
        f32.load
        f32.eq)

  ;; tag || pointer
  (func $eq_rec1 (param i32 i32) (result i32)
        get_local 0
        i32.load
        get_local 1
        i32.load
        call $equal
        )

  ;; tag || pointer pointer
  (func $eq_rec2 (param i32 i32) (result i32)
        get_local 0
        i32.load
        get_local 1
        i32.load
        call $equal
        if ;; fsts equal
          get_local 0
          i32.const 4
          i32.add
          i32.load
          get_local 1
          i32.const 4
          i32.add
          i32.load
          call $equal
          return
        end ;; fsts not equal
        i32.const 0
        )

  ;; tag || int [byte ...]
  (func $eq_string (param $a i32) (param $b i32) (result i32)
        (local $end i32)
        ;; compare lengths
        local.get $a
        local.get $b
        call $eq_int
        if ;; lengths equal
          ;; put length on the stack
          local.get $a
          i32.load
          ;; initiate moving pointers
          local.get $a
          i32.const 4
          i32.add
          local.set $a
          local.get $b
          i32.const 4
          i32.add
          local.set $b
          ;; set end address (length is on the stack)
          local.get $a
          i32.add
          local.set $end
          block
            loop
              ;; break if $a >= $end
              local.get $a
              local.get $end
              i32.ge_u
              br_if 1 ;; branch end of block
              ;; load int8s, compare
              get_local $a
              i32.load8_u
              get_local $b
              i32.load8_u
              i32.ne
              if
                i32.const 0
                return
              end
              ;; increment
              local.get $a
              i32.const 1
              i32.add
              local.set $a
              local.get $b
              i32.const 1
              i32.add
              local.set $b
              br 0 ;; branch beginning of loop
            end
          end
          i32.const 1
          return
        end ;; lengths not equal
        i32.const 0
        )
  )
