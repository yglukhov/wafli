import wasmrt

proc log*(s: cstring, o: JSObject) {.importwasmf: "console.log".}

proc length*(j: JSObject): int {.importwasmp: "length|0".}

proc identity(n: int32): JSObject {.importwasmexpr: "$0".}
proc identity(n: bool): JSObject {.importwasmexpr: "!!$0".}

proc setProp(n: JSObject, k: JSObject, v: JSObject) {.importwasmexpr: "$0[$1] = $2".}

proc setProperty*(n: JSObject, k: cstring, v: int32) {.inline.} =
  setProp(n, JSString(k), identity(v))

proc setProperty*(n: JSObject, k, v: JSString) {.inline.} =
  setProp(n, k, v)

proc setProperty*(n: JSObject, k: cstring, v: bool) {.inline.} =
  setProp(n, JSString(k), identity(v))

proc setProperty*(n: JSObject, k: JSString, v: JSObject) {.inline.} =
  setProp(n, k, v)

proc setProperty*(n: JSObject, k: int, v: int32) {.inline.} =
  setProp(n, identity(k.int32), identity(v))

proc setProperty*(n: JSObject, k: int, v: cstring) {.inline.} =
  setProp(n, identity(k.int32), JSString(v))

proc setProperty*(n: JSObject, k: int, v: bool) {.inline.} =
  setProp(n, identity(k.int32), identity(v))

proc setProperty*(n: JSObject, k: int, v: JSObject) {.inline.} =
  setProp(n, identity(k.int32), v)

proc objToInt(v: JSObject): int32 {.importwasmexpr: "$0".}

proc getObjProperty(n: JSObject, k: JSObject): JSObject {.importwasmexpr: "$0[$1]||null".}

proc getIntProperty*(n: JSObject, idx: int32): int32 {.inline.} =
  objToInt(getObjProperty(n, identity(idx)))

proc getIntProperty*(n: JSObject, idx: JSString): int32 {.inline.} =
  objToInt(getObjProperty(n, idx))

proc getObjProperty*(n: JSObject, idx: int32): JSObject {.inline.} =
  getObjProperty(n, identity(idx))

proc getObjProperty*(n: JSObject, idx: cstring): JSObject {.inline.} =
  getObjProperty(n, JSString(idx))
proc getStrProperty*(n: JSObject, idx: int32): string {.inline.} =
  getObjProperty(n, identity(idx)).JSString

proc getStrProperty*(n: JSObject, idx: cstring): string {.inline.} =
  getObjProperty(n, JSString(idx)).JSString

proc emptyJSArray*(): JSObject {.importwasmp: "[]".}
proc emptyJSObject*(): JSObject {.importwasmp: "{}".}
proc push*(o, v: JSObject) {.importwasmm.}

proc closurize(cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObject {.importwasmexpr: "() => $0($1)".}

proc setInterval(cb: JSObject, ms: uint32): JSObject {.importwasmf.}
proc setTimeout(cb: JSObject, ms: uint32): JSObject {.importwasmf.}

proc setInterval*(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObject {.inline.} =
  setInterval(closurize(cb, ctx), ms)

proc setTimeout*(ms: uint32, cb: proc(ctx: pointer) {.cdecl.}, ctx: pointer): JSObject {.inline.} =
  setTimeout(closurize(cb, ctx), ms)

proc toFixedAux(f: float64, d: int32): JSString {.importwasmm: "toFixed".}

proc toFixed*(f: float, numDecimals: int): string {.inline.} = toFixedAux(f, numDecimals.int32)

proc alert*(s: cstring) {.importwasmf.}
