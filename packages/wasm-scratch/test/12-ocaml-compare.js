require('chai').should();

const fs = require('fs').promises;
const v = require('../lib/value');
const encoding = require('../lib/encoding');

const values = [
  v.unit,
  v.int32(42),
  v.float32(1.25),
  v.true,
  v.false,
  v.left(v.int32(-1)),
  v.right(v.float32(1e18)),
  v.pair(v.unit, v.unit),
  v.right(v.pair(v.pair(v.true, v.false), v.float32(Infinity))),
  v.left(v.string("hello world")),
  v.right(v.pair(v.unit, v.string("right"))),
  v.string("🌹​🎉"), // zero width space lurking
  v.unit
];

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
const export_ = { memory: { object: memory, alloc_p: alloc_p}};

const equal = function(instance, a, b) {
  const a_p = encoding.write(memory, alloc_p, a);
  const b_p = encoding.write(memory, alloc_p, b);
  const res = instance.exports.compare(a_p, b_p);
  return (res == 0 ? true : false);
}

const main = async function() {
  const instance = await fs.readFile("wasm/compare.wasm")
    .then(buf => WebAssembly.compile(buf))
    .then(mod => WebAssembly.instantiate(mod, export_));

  const test = function(a, b, eq) {
    equal(instance, a, b)
      .should.be.equal(eq);
  }

  describe('Ocaml compare', function() {
    it('unit = unit', function() {
      test(v.unit, v.unit, true)
    });

    it('false != true', function() {
      test(v.false, v.true, false);
    });

    it('1 != 2', function() {
      test(v.int32(1), v.int32(2), false);
    });

    it('1 = 1', function() {
      test(v.int32(1), v.int32(1), true);
    });

    it('1. != 2.', function() {
      test(v.float32(1), v.float32(2), false);
    });

    it('1. = 1.', function() {
      test(v.float32(1), v.float32(1), true);
    });

    it('NaN != NaN', function() {
      test(v.float32(NaN), v.float32(NaN), true);
    });

    it('many other combinations', function() {
      values.forEach(a => {
        values.forEach(b => {
          test(a, b, a.toString() === b.toString());
        });
      });
    });
  });
};

main();
