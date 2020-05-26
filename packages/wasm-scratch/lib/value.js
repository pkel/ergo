// This module provides a javascript encoding for our low level wasm values.
// Values are encoded as functions that expect a single argument, namely the
// evaluator object e.
// Were we have done e.left(e.false()), we can now do
// value.left(value.false)(e).
// In a way, value defers the evaluation.
const value = {
  unit : function(e) { return e.unit() },
  false : function(e) { return e.false() },
  true : function(e) { return e.true() },
  int : function(arg) {
    return function(e) {
      return e.int(arg)
    }
  },
  float : function(arg) {
    return function(e) {
      return e.float(arg)
    }
  },
  string : function(arg) {
    return function(e) {
      return e.string(arg)
    }
  }
  left : function(arg) {
    return function(e) {
      return e.left(arg(e))
    }
  },
  right : function(arg) {
    return function(e) {
      return e.right(arg(e))
    }
  },
  pair : function(a, b) {
    return function(e) {
      return e.pair(a(e), b(e))
    }
  },
}
