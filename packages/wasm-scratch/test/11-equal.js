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

const call = function(instance, fnName) {
  const args = [];
  for (var i = 2; i < arguments.length; i += 1) {
    args[i-2] = encoding.write(memory, alloc_p, arguments[i]);
  }
  const res_p = instance.exports[fnName].apply(undefined, args);
  // The current equality does return an int32, not a pointer to a boolean.
  // return encoding.read(memory, res_p);
  return res_p;
}

// main function
const f = async function (){
  const contract = await fs.readFile("wasm/equal.wasm")
    .then(buf => WebAssembly.compile(buf));
  const instance = await WebAssembly.instantiate(contract, export_);

  describe('Equality', function() {
    it('unit = unit', function() {
      call(instance, "equal", v.unit, v.unit).should.be.equal(1);
    });

    it('false != true', function() {
      call(instance, "equal", v.false, v.true).should.be.equal(0);
    });

    it('NaN != NaN', function() {
      call(instance, "equal", v.float32(NaN), v.float32(NaN)).should.be.equal(0);
    });

    it('many other combinations', function() {
      values.forEach(a => {
        values.forEach(b => {
          let str_eq = a.toString() === b.toString() ? 1 : 0;
          call(instance, "equal", a, b).should.be.equal(str_eq);
        })})
    });
  });
};

f();
