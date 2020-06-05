# Dependencies

- Node.js version 12 or higher
- [wabt](https://github.com/WebAssembly/wabt), especially the wat2wasm
program

# Usage

```
npm test
```

# Memory Encoding

Everything is boxed. In memory, a box is an integer (i32) tag followed
by the content. We write `tag content`. The length of the content is
defined by the tag.

## Unit

- Unit() : `0`

## Boolean

- False() : `1`
- True() : `2`

## Numbers

Let x be a 4 byte value.
- Int32(x) : `3 x`
- Float32(x) : `4 x`

## Sum

Let x be a pointer to another box.
- Left(x) : `5 x`
- Right(x) : `6 x`

## Pair

Let x and y be pointers to other boxes.
- Pair(x,y) : `7 x y`

## String

Let x be an n byte value.
- String(x) : `8 n x`

# Future Memory Encoding

We plan to add types for n-tuples(arrays) and records(objects).

## n-Tuple

Let a, b, c, d be pointers to other boxes.
- Tuple(a, b, c) : `9 3 a b c`
- Tuple(a, d) : `9 2 a d`

This might replace the Pair type. Should it?

## Record

Let v1, v2, v3 be pointers to other boxes and fa, fb, fc be pointers to
string boxes for the strings "a", "b", and "c".
- Record({a: v1}) : `10 1 sa v1`
- Record({b: v1, c: v3}) : `10 2 sb v1 sc v3`
- Record({b: v1, a: v2, c: v3}) : `10 3 sb v1 sa v2 sc v3`
- Record({a: v2, b: v1, c: v3}) : `10 3 sa v2 sb v1 sc v3`

Trouble: Should the two last examples be the same? If yes, we have two
options.
1. The compiler and APIs maintain a deterministic order of fields. This
makes comparison easy on the WASM side. Creation of records is less
easy.
2. The WASM compare(x,y) does a lookup of x's field names in y.

## Variants

Let s be a pointer to a string box and v be a pointer to a value.
- Variant(s, v) : `11 s v`

This might replace the Sum type. Should it?

