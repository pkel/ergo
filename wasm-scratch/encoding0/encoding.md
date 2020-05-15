# Memory Encoding (v0)

Everything is boxed. In memory, a box is an integer (i32) tag followed
by the content. We write `tag content`. The length of the content is
defined by the tag.

## Primitive Types

Let x be a 4 byte value.
- Int32(x) : `0 x`
- Float32(x) : `1 x`

Let x be a 8 byte value.
- Int64(x) : `2 x`
- Float64(x) : `3 x`

## Sum

Let x be a pointer to another box.
- Left(x) : `4 x`
- Right(x) : `5 x`

## Pair

Let x and y be pointers to other boxes.
- Pair(x,y) : `6 x y`

## String

Let x be an n byte value.
- String(x) : `7 n x`
