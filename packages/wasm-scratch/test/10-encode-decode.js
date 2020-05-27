require('chai').should();

const v = require('../lib/value');
const encoding = require('../lib/encoding');

const values = [
  v.unit,
  v.int32(42),
  v.float32(1.25),
  v.true,
  v.false,
  v.left(v.int32(-1)),
  v.right(v.float32(NaN)),
  v.pair(v.unit, v.unit),
  v.right(v.pair(v.pair(v.true, v.false), v.float32(Infinity))),
  v.left(v.string("hello world")),
  v.right(v.pair(v.unit, v.string("right"))),
  v.string("🌹​🎉"), // zero width space lurking
  v.unit
];

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);

describe('Encoding', function () {
  describe('write then read', function () {
    for (var i=0; i < values.length; i++) {
      let s = values[i].toString();
      let p = encoding.write(memory, alloc_p, values[i]);
      let b = encoding.read(memory, p).toString();
      it(s, function () {
        s.should.be.equal(b);
      });
    }
  });
});
