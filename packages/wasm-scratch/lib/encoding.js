class Allocator {
  constructor(memory, alloc_p){
    this.memory = memory;
    this.alloc_p = alloc_p;
  }

  // tag: 0
  unit() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 0, true);
    this.alloc_p.value += 4;
    return p;
  }

  // tag: 1
  false() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 1, true);
    this.alloc_p.value += 4;
    return p;
  }

  // tag: 2
  true() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 2, true);
    this.alloc_p.value += 4;
    return p;
  }

  // tag: 3
  // arg: int32
  int32(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 3, true);
    v.setInt32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 4
  // arg: float32
  float32(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 4, true);
    v.setFloat32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 5
  // arg: pointer
  left(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 5, true);
    v.setUint32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 6
  // arg: pointer
  right(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 6, true);
    v.setUint32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 7
  // arg: pointer * pointer
  pair(x, y) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 7, true);
    v.setUint32(p + 4, x, true);
    v.setUint32(p + 8, y, true);
    this.alloc_p.value += 12;
    return p;
  }

  // tag: 8
  // arg: string
  string(x) {
    const b = new TextEncoder('utf8').encode(x);
    const n = b.length;
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 8, true);
    v.setUint32(p + 4, n, true);
    for (var i = 0; i < n; i++) {
      v.setUint8(p + 8 + i, b[i], true)
    }
    this.alloc_p.value += n + 8;
    return p;
  }
}

function write(memory, alloc_p, value) {
  const alloc = new Allocator(memory, alloc_p);
  return value(alloc);
}

const value = require('../lib/value');

function read(memory, address) {
  const view = new DataView(memory.buffer);
  const rec = function(p) {
    switch(view.getUint32(p, true)) {
      case 0:
        return value.unit;
      case 1:
        return value.false;
      case 2:
        return value.true;
      case 3:
        return value.int32(view.getInt32(p + 4, true));
      case 4:
        return value.float32(view.getFloat32(p + 4, true));
      case 5:
        return value.left(rec(view.getUint32(p + 4, true)));
      case 6:
        return value.right(rec(view.getUint32(p + 4, true)));
      case 7:
        const x = rec(view.getUint32(p + 4, true));
        const y = rec(view.getUint32(p + 8, true));
        return value.pair(x,y);
      case 8:
        const n = view.getUint32(p + 4, true);
        const b = new Uint8Array(memory.buffer, p + 8, n);
        return value.string(new TextDecoder('utf8').decode(b));
      default:
        throw `unknown tag ${view.getUint32(p)} at address ${p}`
    }
  }
  return rec(address);
}

module.exports = { read, write }
