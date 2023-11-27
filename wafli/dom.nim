when defined(wasm):
  import ./dom_real
  export dom_real
else:
  import ./dom_dummy
  export dom_dummy
