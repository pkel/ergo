const fs = require('fs').promises;
const enc = require('../lib');
const assert = 

require('chai').should();

function testValues(o) {
  return (
    [ o.unit(),
      o.true(),
      o.false(),
      o.int32(42),
      o.int32(0),
      o.float32(3.14),
      o.float32(0),
      o.left(o.unit()),
      o.left(o.int32(-1)),
      o.right(o.unit()),
      o.right(o.float32(4.4)),
      o.pair(o.unit(), o.unit()),
      o.pair(o.int32(42), o.unit()),
      o.pair(o.unit(), o.int32(42)),
      o.string("abc"),
      o.string("Abc"),
      o.string("aBc"),
      o.string("abC"),
      o.string("abcd"),
      o.string("🌹​🎉"), // zero width space lurking
      o.right(o.pair(o.unit(), o.float32(Infinity))),
      o.left(o.string("hello world")),
      o.right(o.pair(o.unit(), o.string("right"))),
      o.unit()
    ]
  )
}

// main function
async function test(){
  // read wasm contract & compile to actual machine code
  const contract = await fs.readFile("wasm/equal.wasm")
    .then(buf => WebAssembly.compile(buf));

  const memory = new WebAssembly.Memory({initial: 1});
  const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);

  const export_ = { memory: { object: memory, alloc_p: alloc_p}};
  const instance = await WebAssembly.instantiate(contract, export_);

  const js = new enc.Js();
  const write = new enc.Alloc(memory, alloc_p);
  const read = new enc.Read(memory, js);
  const copy = new enc.Read(memory, write);

  // write testValues to linear memory, remember pointers
  const original_pl = testValues(write);
  // copy the values at the pointers, remember new pointers
  const copied_pl = original_pl.map(p => copy.from(p));
  // the new pointers should be equidistant to the first set of pointers
  if (JSON.stringify(original_pl) !== JSON.stringify(copied_pl.map(p => p - copied_pl[0]))) {
    throw {name:"Failed", message:"the copy produced broken pointers"};
    return
  }

  const h = function (x) {
    return {p: x, s: read.from(x)}
  }

  return { l : original_pl.map(x => h(x)),
           r : copied_pl.map(x => h(x)),
           f : instance.exports.equal }
}

// Patrik got very confused by async/await within describe/it.
// It works now, but things look horrible.

describe('equality', async function () {
  it('instantiate', function () {
    return test ()
  });

  let res = await test();

  describe('equality', function () {
    res.l.forEach(l => {
      res.r.forEach(r => {
        it(`${l.s} === ${r.s}`, function () {
          res.f(l.p,r.p).should.be.equal(l.s == r.s ? 1 : 0);
        });
      });
    });
  });
});
