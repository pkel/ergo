(module
  (func (export "init") (result i32)
        i32.const 42)
  (func (export "incr") (param i32) (result i32)
        get_local 0
        i32.const 1
        i32.add)
  (func (export "decr") (param i32) (result i32)
        get_local 0
        i32.const 1
        i32.sub)
  )
