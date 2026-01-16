switch("path", "$projectDir/..")

when defined(wasm):
  --os:linux
  --cpu:wasm32
  --threads:off
  --cc:clang
  --gc:orc
  --d:release
  --d:danger
  --nomain
  --opt:size
  --stackTrace:off
  --d:noSignalHandler
  --exceptions:goto
  --d:nimPreviewFloatRoundtrip # Avoid using sprintf as it's not available in wasm

  let llTarget = "wasm32-unknown-unknown"

  switch("passC", "--target=" & llTarget)
  switch("passL", "--target=" & llTarget)

  switch("passC", "-I/usr/include") # Wouldn't compile without this :(

  switch("passC", "-flto") # Important for code size!

  # gc-sections seems to not have any effect
  var linkerOptions = "-nostdlib -Wl,--no-entry,--allow-undefined,--gc-sections,--strip-all"

  switch("clang.options.linker", linkerOptions)
  switch("clang.cpp.options.linker", linkerOptions)

else:
  --passC:"-Wno-incompatible-pointer-types"
  --debugger:native
