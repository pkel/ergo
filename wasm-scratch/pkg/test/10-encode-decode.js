const enc = require('../lib')
const chai = require('chai')

const values = function (o) {
  return (
    [ o.unit(),
      o.int32(42),
      o.float32(1.25),
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

const js = new enc.Js ();
const reference = values(js);

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
const write = new enc.Alloc(memory, alloc_p)
const read = new enc.Read(memory, js)

const reread = values(write).map(p => read.from(p));

chai.should();

describe('encode then decode', function () {
  it('should be equal', function () {
    for (var i=0; i < reference.length; i++) {
      reread[i].should.be.equal(reference[i]);
    }
  });
});
