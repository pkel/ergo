// This module provides a Javascript encoding for our low level wasm values.
// Values are encoded as functions that expect a single argument, namely the
// evaluator object e.
// Where we have done e.left(e.false()), we can now do
// value.left(value.false)(e).
// In a way, we defer the evaluation.

// This evaluator converts a value to a string.
const toString = {
  unit: () => `unit`,
  false: () => `false`,
  true: () => `true`,
  int32: a => `int32(${a})`,
  float32: a => `float32(${a})`,
  string: a => `string(${a})`,
  left: a => `left(${a})`,
  right: a => `right(${a})`,
  pair: (a, b) => `pair(${b},${a})`
}

// Use the string evaluator for, e.g., value.unit.toString().
const value = function(f) {
  f.toString = () => f(toString);
  return f;
}

// Define evaluation rules.
const values = {
  unit: value(e => e.unit()),
  false: value(e => e.false()),
  true: value(e => e.true()),
  int32: a => value(e => e.int32(a)),
  float32: a => value(e => e.float32(a)),
  string: a => value(e => e.string(a)),
  left: a => value(e => e.left(a(e))),
  right: a => value(e => e.right(a(e))),
  pair: (a, b) => value(e => e.pair(a(e), b(e))),
}

module.exports = values;
