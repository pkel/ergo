test: equal.wasm
	node test-js-side.js
	node test-equal.js

%.wasm: %.wat
	wat2wasm $^
