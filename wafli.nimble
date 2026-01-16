# Package

version       = "0.1.0"
author        = "Yuriy Glukhov"
description   = "Reactive web application framework that compiles to WebAssembly"
license       = "MIT"


# Dependencies

requires "nim >= 2.0"
requires "yasync"
requires "wasmrt"

task samples, "Build samples":
  for f in listFiles("tests"):
    let n = f[6 .. ^1]
    if n.startsWith("t") and n.endsWith(".nim"):
      exec "nim c -d:wasm --out:" & n & ".wasm tests/" & n
      exec "wasm2html " & n & ".wasm " & n[0 .. ^5] & ".html"
      # exec "wasm2wat " & n & ".wasm -o " & n[0 .. ^5] & ".wat"
  when defined(linux):
    try: exec "xdg-open test_all.html" except: discard

task test, "Build and run tests":
  for f in listFiles("tests"):
    let n = f[6 .. ^1]
    if n.startsWith("t") and n.endsWith(".nim"):
      exec "nim c -d:wasm --out:" & n & ".wasm tests/" & n
      exec "node tests/test_node_runner.js " & n & ".wasm"
      # exec "wasm2wat " & n & ".wasm -o " & n[0 .. ^5] & ".wat"
