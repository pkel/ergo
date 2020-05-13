const fs = require("fs").promises;

function div4 (x) { return Math.floor(x/4) }

// MVP memory management:
// - we allocate by incrementing an allocation pointer.
// - freeing memory is out of scope.
class Memory {
  constructor() {
    // wasm linear memory instance
    this.memory = new WebAssembly.Memory ({initial: 1});
    // allocation pointer
    this.alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
  }

  // In order to read values from wasm memory, we cast the raw content (buffer)
  // to a typed array.
  read_int32(p) {
    const i32 = new Uint32Array(this.memory.buffer);
    return i32[div4(p)];
  }

  // The same trick works for storing. We store the value to the allocation
  // pointer and then increment the pointer.
  store_int32(x) {
    const p = this.alloc_p.value;
    var i32 = new Uint32Array(this.memory.buffer);
    i32[div4(p)] = x;
    this.alloc_p.value += 4;
    return p;
  }

  to_string_int32() {
    const i32 = new Uint32Array(this.memory.buffer);
    return i32.slice(0, div4(this.alloc_p)).join('\t');
  }

  get export_() {
    return { object: this.memory, alloc_p: this.alloc_p };
  }
}

// contract initialization
async function init (contract) {
  var memory = new Memory();
  var export_ = { memory : memory.export_ };
  const instance = await WebAssembly.instantiate(contract, export_);

  const state_p = instance.exports.init();
  return memory.read_int32(state_p);
}

// contract clause invocation
async function call (contract, clause, state, payload) {
  var memory = new Memory();
  var export_ = { memory : memory.export_ };
  const instance = await WebAssembly.instantiate(contract, export_);

  state_p = memory.store_int32(state);
  payload_p = memory.store_int32(payload);

  response_p = instance.exports[clause](state_p, payload_p);

  return memory.read_int32(response_p);
}

// main function
async function test(){
  // read wasm contract & compile to actual machine code
  const contract = await fs.readFile("./counter.wasm")
    .then(buf => WebAssembly.compile(buf));

  // init contract
  var state = await init(contract);
  console.log('init: ' + state);

  // invoke some clauses
  async function f(clause) {
    state = await call(contract, clause, state, 1);
    console.log(clause + ': ' + state);
  }
  await f("incr")
  await f("decr")
  await f("incr")
  await f("incr")
  await f("incr")
  await f("decr")
  await f("decr")
  await f("decr")
}

test()
