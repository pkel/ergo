# Dependencies

- Node.js version 12 or higher
- [wabt](https://github.com/WebAssembly/wabt), especially the wat2wasm
  program

# Usage

```
npm test
```

# Memory Encoding

Everything is boxed. In memory, a box is an unsigned integer tag followed
by the content. The following encoding is implemented in
`lib/encoding.js` (both read and write).

`null` has tag 0 and no content:
`<i32u> 0`

`true` has tag 1 and no content:
`<i32u> 1`

`false` has tag 2 and no content:
`<i32u> 2`

Number x has tag 3 and 8 bytes of content:
`<i32u> 3 | <f64> x`

String x has tag 4 and (n + 4) bytes of content, where n denotes the
byte-length of x:
`<i32u> 4 | <i32u> n | <i8u> x[0] | <i8u> x[1] | ...`

Array x has tag 5 and (n * 4 + 4) bytes of content, where n denotes the
size of the array. Each element of x is pointer to an arbitrary box.
`<i32u> 5 | <i32u> n | <addr> x[0] | <addr> x[1] | ...`

Record x is translated to a list l of key-value pairs. The list does not
contain duplicate keys and is *sorted* by keys. Each key is a pointer to
a string box. Each value is a pointer to an arbitrary box. In wasm
memory, x has tag 6 and (n * 8 + 4) bytes of content, where n is the
length of l:
`<i32u> 6 | <i32u> n | <addr> x[0][0] | <addr> x[0][1] | <addr> x[1][0] | <addr> x[1][1] | ...`

Left(x) has tag 7 and 4 bytes of content. x is a pointer to an arbitrary
box:
`<i32u> 7 | <addr> x`

Right(x) has tag 8 and 4 bytes of content. x is a pointer to an arbitrary
box:
`<i32u> 8 | <addr> x`

BigInt x has tag 9 and 8 bytes of content. x is casted to the set of
singed 64-bit integers:
`<i32u> 9 | <i64s> x`
