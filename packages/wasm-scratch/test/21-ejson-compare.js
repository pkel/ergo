require('chai').should();

const fs = require('fs').promises;
const encoding = require('../lib/ejson-enc.js');

const values = [
];

const memory = new WebAssembly.Memory({initial: 1});
const alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
const export_ = { memory: { object: memory, alloc_p: alloc_p}};

const equal = function(instance, a, b) {
  const a_p = encoding.write(memory, alloc_p, a);
  const b_p = encoding.write(memory, alloc_p, b);
  const res = instance.exports.compare(a_p, b_p);
  return (res === 0 ? true : false);
}

const main = async function() {
  const instance = await fs.readFile("wasm/ejson-compare.wasm")
    .then(buf => WebAssembly.compile(buf))
    .then(mod => WebAssembly.instantiate(mod, export_));

  const test = function(a, b) {
    equal(instance, a, b)
      .should.be.equal(a === b);
  }

  describe('EJson compare', function() {
    it('null = null', function() {
      test(null, null)
    });

    it('false != true', function() {
      test(false, true)
    });

    it('1 = 1', function() {
      test(1, 1);
    });

    it('null != 1.2', function() {
      test(null, 1.2);
    });

    it('0 != 1', function() {
      test(0, 1);
    });

    it('1.1 != 1.2', function() {
      test(1.1, 1.2);
    });

    it('left != right', function() {
      test({left:null}, {right:null});
    });

    it('left(a) != left(b)', function() {
      test({left:null}, {left:false});
    });

    it('"a" != "bc"', function() {
      test('a','bc');
    });

    // it('NaN = NaN', function() {
      // test(NaN, NaN);
    // });

    it('many other combinations', function() {
      values.forEach(a => {
        values.forEach(b => {
          test(a, b);
        });
      });
    });
  });
};

main();
