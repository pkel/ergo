const fs = require("fs").promises;
const enc = require('./encoding.js')

function testValues(o) {
  return (
    [ o.unit(),
      o.int32(42),
      o.int32(0),
      o.float32(3.14),
      o.float32(0),
      o.left(o.unit()),
      o.left(o.int32(-1)),
      o.right(o.unit()),
      o.right(o.float32(NaN)),
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
  const contract = await fs.readFile("./equal.wasm")
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
  if (JSON.stringify(original_pl) != JSON.stringify(copied_pl.map(p => p - copied_pl[0]))) {
    console.log("the copy produced broken pointers");
    return
  }

  original_pl.forEach(l => {
    copied_pl.forEach(r => {
      let is = instance.exports.equal(l,r);
      let should = read.from(l) == read.from(r);
      if (is != should) {
        console.log("Failure: eq(" + read.from(l) + ", " + read.from(r) + ") = " + is);
      } else {
        // console.log("Success: eq(" + read.from(l) + ", " + read.from(r) + ") = " + is);
      }
    })});
}

test()
