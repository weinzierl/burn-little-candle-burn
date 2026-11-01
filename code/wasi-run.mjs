// Run a wasm32-wasip1 binary with Node's built-in WASI (no extra tools).
// usage: node wasi-run.mjs <file.wasm>   (run from the code/ directory)
import { readFile } from 'node:fs/promises';
import { WASI } from 'node:wasi';

const wasi = new WASI({
  version: 'preview1',
  args: [process.argv[2]],
  env: {},
  preopens: { '.': '.' },
});
const module = await WebAssembly.compile(await readFile(process.argv[2]));
const instance = await WebAssembly.instantiate(module, wasi.getImportObject());
wasi.start(instance);
