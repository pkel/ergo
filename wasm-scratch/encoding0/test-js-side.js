var enc = require('./encoding.js')

function test(o) {
  return (
    [ o.unit(),
      o.int32(42),
      o.float32(3.14),
      o.left(o.int32(-1)),
      o.right(o.float32(NaN)),
      o.pair(o.unit(), o.unit()),
      o.right(o.pair(o.unit(), o.float32(Infinity))),
      o.left(o.string("hello world")),
      o.right(o.pair(o.unit(), o.string("right"))),
      o.string("🌹​🎉"), // zero width space lurking
      o.unit()
    ]
  )
}

console.log("reference output:")
js = new enc.Js ()
test(js).forEach(x => console.log("  " + x))

console.log("encode, then decode:")
memory = new WebAssembly.Memory({initial: 1});
alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
write = new enc.Alloc(memory, alloc_p)
read = new enc.Read(memory, js)
test(write).forEach(p => console.log("  " + read.from(p)));
