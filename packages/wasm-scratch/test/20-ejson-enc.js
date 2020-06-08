expect = require('chai').expect;

const encoding = require('../lib/ejson-enc');

const values = [
  true,
  false,
  0,
  3.14,
  Infinity,
  'a string',
  '🌹​🎉', // zero width space lurking
  [1, 2, 3],
  {field1: 'value1'},
  [null, {}, false, 0, [], {left: null}],
  {left: null},
  {right: 'string'},
  {left: 'either', key: 'value'} // this an ordinary object
];

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);

describe('EJson Encoding', function () {
  describe('write values to wasm memory, read back, compare', function () {
    for (var i=0; i < values.length; i++) {
      let a = values[i];
      it(JSON.stringify(a), function () {
        let p = encoding.write(memory, alloc_p, a);
        let b = encoding.read(memory, p);
        expect(a).to.deep.equal(b);
      });
    };
  });
});
