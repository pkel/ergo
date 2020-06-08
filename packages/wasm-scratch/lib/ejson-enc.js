class Allocator {
  constructor(memory, alloc_p) {
    this.memory = memory;
    this.alloc_p = alloc_p;
  }

  // <i32u> 0
  null_() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 0, true);
    this.alloc_p.value += 4;
    return p;
  }

  // <i32u> 1
  false_() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 1, true);
    this.alloc_p.value += 4;
    return p;
  }

  // <i32u> 2
  true_() {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 2, true);
    this.alloc_p.value += 4;
    return p;
  }

  // <i32u> 3 || <f64> x
  number(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 3, true);
    v.setFloat64(p + 4, x, true);
    this.alloc_p.value += 4 + 8;
    return p;
  }

  // <i32u> 4 || len(bytes) || <i8u> bytes[0] || bytes[1] || ...
  string(x) {
    const b = new TextEncoder('utf8').encode(x);
    const n = b.length;
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 4, true);
    v.setUint32(p + 4, n, true);
    for (let i = 0; i < n; i++) {
      v.setUint8(p + 8 + i, b[i], true)
    }
    this.alloc_p.value += n + 8;
    return p;
  }

  // <i32u> 5 || len(x) || x[0] || x[1] || ...
  array(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 5, true);
    this.alloc_p.value += 8; // one spare i32 for the length
    let length = 0;
    x.forEach(x => {
      v.setUint32(this.alloc_p.value, x, true);
      this.alloc_p.value += 4;
      length += 1;
    });
    v.setUint32(p + 4, length, true);
    return p;
  }

  // <i32u> 6 || len(x) || x[0][0] || x[0][1] || x[1][0] || x[1][1] || ...
  object(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 6, true);
    let length = 0;
    this.alloc_p.value += 8; // one spare i32 for the length
    x.forEach(x => {
      v.setUint32(this.alloc_p.value, x[0], true);
      this.alloc_p.value += 4;
      v.setUint32(this.alloc_p.value, x[1], true);
      this.alloc_p.value += 4;
      length += 1;
    });
    v.setUint32(p + 4, length, true);
    return p;
  }

  // <i32u> 7 || x
  left(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 7, true);
    v.setUint32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }

  // <i32u> 8 || x
  right(x) {
    const p = this.alloc_p.value;
    const v = new DataView(this.memory.buffer);
    v.setUint32(p, 8, true);
    v.setUint32(p + 4, x, true);
    this.alloc_p.value += 8;
    return p;
  }
}

function write(memory, alloc_p, x) {
  const alloc = new Allocator(memory, alloc_p);
  function recurse(x) {
    switch (typeof x) {
      case 'boolean':
        if (x) {
          return alloc.true_();
        } else {
          return alloc.false_();
        }
        break;
      case 'string':
        return alloc.string(x);
      case 'number':
        return alloc.number(x);
      case 'object':
        if (x === null) {
          return alloc.null_();
        } else if (Array.isArray(x)) {
          return alloc.array(x.map(x => recurse(x)));
        } else {
          let keys = Object.getOwnPropertyNames(x).sort();
          // TODO: Ask Jerome, whether left/right translation is correct:
          if ( keys.length === 1 && keys[0] === 'left' ) {
            return alloc.left(recurse(x.left));
          } else if ( keys.length === 1 && keys[0] === 'right' ) {
            return alloc.right(recurse(x.right));
          } else {
            return alloc.object(keys.map(k => [recurse(k), recurse(x[k])]));
          };
        };
        break;
      default:
        throw new Error(`unknown type: ${typeof x}`);
    };
  };
  return recurse(x);
};

function read(memory, p) {
  const view = new DataView(memory.buffer);
  function recurse(p) {
    switch(view.getUint32(p, true)) {
      case 0:
        return null;
      case 1:
        return false;
      case 2:
        return true;
      case 3: // number
        return view.getFloat64(p + 4, true);
      case 4: { // string
        let n = view.getUint32(p + 4, true);
        let b = new Uint8Array(memory.buffer, p + 8, n);
        return (new TextDecoder('utf8').decode(b));
      };
      case 5: { // array
        let n = view.getUint32(p + 4, true);
        let array = [];
        let pos = p + 8;
        for (let i=0; i < n; i++) {
          array[i] = recurse(view.getUint32(pos, true));
          pos += 4;
        };
        return array;
      };
      case 6: { // object
        let n = view.getUint32(p + 4, true);
        let object = {};
        let pos = p + 8;
        for (let i=0; i < n; i++) {
          let key = recurse(view.getUint32(pos, true));
          if (typeof key !== 'string') {
            throw new Error('invalid value');
          };
          object[key] = recurse(view.getUint32(pos + 4, true));
          pos += 8;
        };
        return object;
      };
      case 7: // left
        return {left: recurse(view.getUint32(p + 4, true))};
      case 8: // right
        return {right: recurse(view.getUint32(p + 4, true))};
      default:
        throw new Error('unknown tag');
    };
  };
  return recurse(p);
};

module.exports = { write, read };
