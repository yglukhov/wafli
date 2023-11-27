# Package

version       = "0.1.0"
author        = "Yuriy Glukhov"
description   = "A new awesome nimble package"
license       = "MIT"


# Dependencies

requires "nim >= 2.0"
requires "yasync"
requires "wasmrt"

task test, "Build tests":
  for f in listFiles("tests"):
    let n = f[6 .. ^1]
    if n.startsWith("t") and n.endsWith(".nim"):
      exec "nim c -d:wasm --out:" & n & ".wasm tests/" & n
      exec "wasm2html " & n & ".wasm " & n[0 .. ^5] & ".html"
  when defined(linux):
    try: exec "xdg-open test_all.html" except: discard
