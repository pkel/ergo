(module
  (type $compare (func (param i32 i32) (result i32)))
  (import "memory" "object" (memory $mem 1))
  (table $tab 9 funcref)
  (func $cmp_i32u_stack
    (type $compare)
    (local.get 0)
    (local.get 1)
    (i32.lt_u)
    (if
      (result i32)
      (then (i32.const -1))
      (else
        (local.get 0)
        (local.get 1)
        (i32.gt_u)
      )
    )
  )
  (func $cmp_i32u_pointer
    (type $compare)
    (local.get 0)
    (i32.load)
    (local.get 1)
    (i32.load)
    (call $cmp_i32u_stack)
  )
  (func $cmp_f64_stack (param f64 f64) (result i32)
    (local.get 0)
    (local.get 1)
    (f64.lt)
    (if
      (result i32)
      (then (i32.const -1))
      (else (local.get 0) (local.get 1) (f64.gt))
    )
  )
  (func $cmp_f64_pointer
    (type $compare)
    (local.get 0)
    (f64.load)
    (local.get 1)
    (f64.load)
    (call $cmp_f64_stack)
  )
  (func $cmp_ejson
    (type $compare)
    (local $res i32)
    ;; compare tags
    (local.get 0)
    (local.get 1)
    (call $cmp_i32u_pointer)
    ;; store result
    (local.tee $res)
    ;; cmp(tag0, tag1) = 0
    (i32.const 0)
    (i32.eq)
    (if ;; tags are equal
      (result i32)
      (then
        ;; increment pointer to first argument
        (local.get 0)
        (i32.const 4)
        (i32.add)
        ;; increment pointer to second argument
        (local.get 1)
        (i32.const 4)
        (i32.add)
        ;; load tag and jump
        (local.get 0)
        (i32.load)
        (call_indirect (type $compare))
      )
      (else (local.get $res))
    )
  )
  (func $cmp_nullary (type $compare) (i32.const 0))

  (func $cmp_unary
    (type $compare)
    (local.get 0)
    (i32.load)
    (local.get 1)
    (i32.load)
    (call $cmp_ejson)
  )

  (func $cmp_string
    (type $compare)
    (local $res i32)
    (local $end i32)
    (local.get 0)
    (local.get 1)
    (call $cmp_i32u_pointer)
    (local.tee $res)
    (i32.const 0)
    (i32.eq)
    (if
      (result i32)
      (then
        (local.get 0)
        (i32.load)
        (local.get 0)
        (i32.const 3)
        (i32.add)
        (local.tee 0)
        (i32.add)
        (local.set $end)
        (local.get 1)
        (i32.const 3)
        (i32.add)
        (local.set 1)
        (loop
          (result i32)
          (local.get 0)
          (local.get $end)
          (i32.ge_u)
          (if
            (result i32)
            (then (i32.const 0))
            (else
              (local.get 0)
              (i32.const 1)
              (i32.add)
              (local.tee 0)
              (i32.load8_u)
              (local.get 1)
              (i32.const 1)
              (i32.add)
              (local.tee 1)
              (i32.load8_u)
              (call $cmp_i32u_stack)
              (local.tee $res)
              (i32.const 0)
              (i32.eq)
              (br_if 1)
              (local.get $res)
            )
          )
        )
      )
      (else (local.get $res))
    )
  )

  (export "compare" (func $cmp_ejson))

  (elem $tab (offset (i32.const 0))
        $cmp_nullary     ;; null
        $cmp_nullary     ;; false
        $cmp_nullary     ;; true
        $cmp_f64_pointer ;; number
        $cmp_string      ;; string
        $cmp_nullary     ;; TODO: array
        $cmp_nullary     ;; TODO: object
        $cmp_unary       ;; left
        $cmp_unary       ;; right
        )
)
