'use strict';

const expect = require('chai').expect;

const encoding = require('../lib/encoding');

const values = [
  null,
  true,
  false,
  0,
  3.14,
  Infinity,
  NaN,
  'a string',
  '🌹​🎉', // zero width space lurking
  [1, 2, 3],
  {field1: 'value1'},
  [null, {}, false, 0, [], {left: null}],
  {left: null},
  {right: 'string'},
  {left: 'either', key: 'value'}, // this an ordinary object
  0n,
  BigInt(Number.MAX_SAFE_INTEGER) << 5n
];

function toString(a) {
  try {
    return JSON.stringify(a);
  } catch (e) {
    return a.toString();
  }
}

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: 'i32', mutable: true}, 0);

describe('Wasm Encoding', function () {
  describe('write values to wasm memory, read back, compare', function () {
    for (let i=0; i < values.length; i++) {
      let a = values[i];
      it(toString(a), function () {
        let p = encoding.write(memory, alloc_p, a);
        let b = encoding.read(memory, p);
        expect(a).to.deep.equal(b);
      });
    }
  });
});
