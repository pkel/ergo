class Js {
  unit() {
    return `unit()`
  }

  int32(x) {
    return `int32(${x})`
  }

  float32(x) {
    return `float32(${x})`
  }

  left(x) {
    return `left(${x})`
  }

  right(x) {
    return `right(${x})`
  }

  pair(x, y) {
    return `pair(${x}, ${y})`
  }

  string(x) {
    return `string("${x}")`
  }
}

class Alloc {
  constructor(memory, alloc_p){
    this.memory = memory;
    this.alloc_p = alloc_p;
  }

  // tag: 0
  unit() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 0);
    this.alloc_p.value += 4;
    return p;
  }

  // tag: 1
  // arg: int32
  int32(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 1);
    v.setInt32(p + 4, x);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 2
  // arg: float32
  float32(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 2);
    v.setFloat32(p + 4, x);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 3
  // arg: pointer
  left(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 3);
    v.setUint32(p + 4, x);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 4
  // arg: pointer
  right(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 4);
    v.setUint32(p + 4, x);
    this.alloc_p.value += 8;
    return p;
  }

  // tag: 5
  // arg: pointer * pointer
  pair(x, y) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 5);
    v.setUint32(p + 4, x);
    v.setUint32(p + 8, y);
    this.alloc_p.value += 12;
    return p;
  }

  // tag: 6
  // arg: string
  string(x) {
    const b = new TextEncoder('utf8').encode(x);
    const n = b.length;
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 6);
    v.setUint32(p + 4, n);
    for (var i = 0; i < n; i++) {
      v.setUint8(p + 8 + i, b[i])
    }
    this.alloc_p.value += n + 8;
    return p;
  }
}

class Read {
  constructor(memory, o) {
    this.memory = memory;
    this.o = o;
  }

  from(p) {
    const v = new DataView(this.memory.buffer);
    switch(v.getUint32(p)) {
      case 0:
        return this.o.unit();
      case 1:
        return this.o.int32(v.getInt32(p + 4));
      case 2:
        return this.o.float32(v.getFloat32(p + 4));
      case 3:
        return this.o.left(this.from(v.getUint32(p + 4)));
      case 4:
        return this.o.right(this.from(v.getUint32(p + 4)));
      case 5:
        const x = this.from(v.getUint32(p + 4));
        const y = this.from(v.getUint32(p + 8));
        return this.o.pair(x,y);
      case 6:
        const n = v.getUint32(p + 4);
        const b = new Uint8Array(this.memory.buffer, p + 8, n);
        return this.o.string(new TextDecoder('utf8').decode(b));
      default:
        throw `unknown tag ${v.getInt32(p)} at address ${p}`
    }
  }
}

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
js = new Js ()
test(js).forEach(x => console.log("  " + x))

console.log("encode, then decode:")
memory = new WebAssembly.Memory({initial: 1});
alloc_p = new WebAssembly.Global({value: "i32", mutable: true}, 0);
write = new Alloc(memory, alloc_p)
read = new Read(memory, js)
test(write).forEach(p => console.log("  " + read.from(p)));
