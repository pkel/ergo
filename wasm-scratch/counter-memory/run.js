const fs = require("fs").promises;

function div4 (x) { return Math.floor(x/4) }

class Memory {
  constructor() {
    this.memory = new WebAssembly.Memory ({initial: 1});
    this.alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
  }

  get export_() {
    return { object: this.memory, alloc_p: this.alloc_p };
  }

  read_int32(p) {
    const i32 = new Uint32Array(this.memory.buffer);
    return i32[div4(p)];
  }

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
}

async function init (contract) {
  var memory = new Memory();
  var export_ = { memory : memory.export_ };
  const instance = await WebAssembly.instantiate(contract, export_);

  const state_p = instance.exports.init();
  return memory.read_int32(state_p);
}

async function call (contract, clause, state, payload) {
  var memory = new Memory();
  var export_ = { memory : memory.export_ };
  const instance = await WebAssembly.instantiate(contract, export_);

  state_p = memory.store_int32(state);
  payload_p = memory.store_int32(payload);

  response_p = instance.exports[clause](state_p, payload_p);

  return memory.read_int32(response_p);
}

async function test(){
  const contract = await fs.readFile("./counter.wasm")
    .then(buf => WebAssembly.compile(buf));

  var state = await init(contract);
  console.log('init: ' + state);

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
