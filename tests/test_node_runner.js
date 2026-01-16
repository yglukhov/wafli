#!/usr/bin/env node

process.on('unhandledRejection', error => {
  console.log('Unhandled promise rejection', error);
  process.exit(1)
});

const fs = require('fs');

// Check if wasm file path is provided
if (process.argv.length < 3) {
  console.error('Usage: node test_node_runner.js <wasm-file>');
  process.exit(1);
}

const wasmFile = process.argv[2];

// Set up jsdom environment first - this will create a browser-like environment
const { JSDOM } = require('./jsdom-bundle.js');

// Create a virtual DOM environment
const dom = new JSDOM("", {
  url: 'http://localhost:3000',
  pretendToBeVisual: true,
  // resources: 'usable',
  runScripts: 'dangerously'
});

// Set up global browser environment
global.window = dom.window;
for (i of ['document', 'navigator', 'requestAnimationFrame', 'cancelAnimationFrame', 'localStorage', 'sessionStorage']) {
  global[i] = window[i];
}

// wasmrt bootstrap function from the library
function runNimWasm(w){for(i of WebAssembly.Module.exports(w)){n=i.name;if(n[0]==';'){new Function('m',n)(w);break}}}

// Use the wasmrt approach to run the WASM
WebAssembly.compile(fs.readFileSync(wasmFile)).then(runNimWasm)
