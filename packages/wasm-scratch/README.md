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
