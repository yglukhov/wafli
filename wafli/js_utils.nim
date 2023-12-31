import wasmrt

proc log*(s: cstring, o: JSObj) {.importwasmf: "console.log".}

proc length*(j: JSObj): int {.importwasmp.}
proc strWriteOut(j: JSObj, p: pointer, len: int): int {.importwasmraw: """
return new TextEncoder().encodeInto(_nimo[$0], new Uint8Array(_nima.buffer, $1, $2)).written
""".}

proc jsStringToStr*(v: JSObj): string =
  if not v.isNil:
    let sz = length(v) * 3
    result.setLen(sz)
    if sz != 0:
      let actualSz = strWriteOut(v, addr result[0], sz)
      result.setLen(actualSz)

proc setProp(n: JSObj, kIsStr: bool, k: pointer, vIsStr: bool, v: pointer) {.importwasmraw: """
_nimo[$0][$1?_nimsj($2):$2] = $3?_nimsj($4):$4
""".}

proc setProperty*(n: JSObj, k, v: cstring) {.inline.} =
  setProp(n, true, cast[pointer](k), true, cast[pointer](v))

proc setProperty*(n: JSObj, k: cstring, v: int32) {.inline.} =
  setProp(n, true, cast[pointer](k), false, cast[pointer](v))

proc setProperty*(n: JSObj, k: int, v: cstring) {.inline.} =
  setProp(n, false, cast[pointer](k), true, cast[pointer](v))

proc setProperty*(n: JSObj, k: int, v: int32) {.inline.} =
  setProp(n, false, cast[pointer](k), false, cast[pointer](v))

proc setProp(n: JSObj, kIsString: bool, k: pointer, v: JSObj) {.importwasmraw: """
_nimo[$0][$1?_nimsj($2):$2] = _nimo[$3]
"""}

proc setProperty*(n: JSObj, k: cstring, v: JSObj) {.inline.} =
  setProp(n, true, cast[pointer](k), v)

proc setProperty*(n: JSObj, k: int, v: JSObj) {.inline.} =
  setProp(n, false, cast[pointer](k), v)

proc getIntProperty(n: JSObj, isStr: bool, k: pointer): int32 {.importwasmraw: """
return _nimo[$0][$1?_nimsj($2):$2]
""".}

proc getObjProperty(n: JSObj, isStr: bool, k: pointer): JSObj {.importwasmraw: """
return _nimok(_nimo[$0][$1?_nimsj($2):$2])
""".}

proc getIntProperty*(n: JSObj, idx: int32): int32 {.inline.} =
  getIntProperty(n, false, cast[pointer](idx))

proc getIntProperty*(n: JSObj, idx: cstring): int32 {.inline.} =
  getIntProperty(n, true, cast[pointer](idx))

proc getObjProperty*(n: JSObj, idx: int32): JSObj {.inline.} =
  getObjProperty(n, false, cast[pointer](idx))

proc getObjProperty*(n: JSObj, idx: cstring): JSObj {.inline.} =
  getObjProperty(n, true, cast[pointer](idx))

proc getStrProperty*(n: JSObj, idx: int32): string {.inline.} =
  jsStringToStr(getObjProperty(n, idx))

proc getStrProperty*(n: JSObj, idx: cstring): string {.inline.} =
  jsStringToStr(getObjProperty(n, idx))

proc emptyJSArray*(): JSObj {.importwasmp: "[]".}
proc emptyJSObject*(): JSObj {.importwasmp: "{}".}
proc push*(o, v: JSObj) {.importwasmm.}
proc jsStr*(a: cstring): JSObj {.importwasmp: "_nimsj($0)".}
