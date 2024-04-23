import wasmrt

proc log*(s: cstring, o: JSObj) {.importwasmf: "console.log".}

proc length*(j: JSObj): int {.importwasmp.}
proc strWriteOut(j: JSObj, p: pointer, len: int): int {.importwasmf: "_nimws".}

proc jsStringToStr*(v: JSObj): string =
  if not v.isNil:
    let sz = length(v) * 3
    result.setLen(sz)
    if sz != 0:
      let actualSz = strWriteOut(v, addr result[0], sz)
      result.setLen(actualSz)

proc setProp(n: JSObj, kIsStr: bool, k: pointer, vIsStr: bool, v: pointer) {.importwasmexpr: """
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

proc setProp(n: JSObj, kIsString: bool, k: pointer, v: JSObj) {.importwasmexpr: """
_nimo[$0][$1?_nimsj($2):$2] = _nimo[$3]
"""}

proc setProperty*(n: JSObj, k: cstring, v: JSObj) {.inline.} =
  setProp(n, true, cast[pointer](k), v)

proc setProperty*(n: JSObj, k: int, v: JSObj) {.inline.} =
  setProp(n, false, cast[pointer](k), v)

proc getIntProperty(n: JSObj, isStr: bool, k: pointer): int32 {.importwasmexpr: """
_nimo[$0][$1?_nimsj($2):$2]
""".}

proc getObjProperty(n: JSObj, isStr: bool, k: pointer): JSObj {.importwasmexpr: """
_nimo[$0][$1?_nimsj($2):$2]
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
proc nimsj(a: pointer): JSObj {.importwasmf.}
proc jsStr*(a: cstring): JSObj {.inline.} = nimsj(a)

proc setIntervalAux(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObj {.importwasmexpr: """
setInterval(() => {_nime._dvi($1, $2)}, $0)
""".}

proc setTimeoutAux(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObj {.importwasmexpr: """
setTimeout(() => {_nime._dvi($1, $2)}, $0)
""".}

proc setInterval*(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObj {.inline.} =
  defineDyncall("vi")
  setIntervalAux(ms, cb, ctx)

proc setTimeout*(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObj {.inline.} =
  defineDyncall("vi")
  setTimeoutAux(ms, cb, ctx)

proc toFixedAux(f: float64, d: int32): JSObj {.importwasmm: "toFixed".}

proc toFixed*(f: float, numDecimals: int): string {.inline.} = jsStringToStr(toFixedAux(f, numDecimals.int32))

proc alert*(s: cstring) {.importwasmf.}
