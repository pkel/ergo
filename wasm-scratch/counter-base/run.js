const { readFileSync } = require("fs");

const run = async () => {
  const buffer = readFileSync("./counter.wasm");
  const module = await WebAssembly.compile(buffer);
  const instance = await WebAssembly.instantiate(module);

  console.log(instance.exports.init());
  console.log(instance.exports.incr(41));
  console.log(instance.exports.decr(43));
};

run();
