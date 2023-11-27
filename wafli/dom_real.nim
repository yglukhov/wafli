import std/[tables, strutils]
import wasmrt
import ./[reactive, types, js_utils]

export setProperty, isNil

type
  Document* = object of JSObj
  Node* = object of JSObj

  ClassList = object of JSObj

proc document*(): Document {.importwasmp.}
proc body*(d: Document): Node {.importwasmp.}
proc head*(d: Document): Node {.importwasmp.}
proc documentElement*(d: Document): Node {.importwasmp.}
proc createElement*(d: Document, s: cstring): Node {.importwasmm.}
proc createTextNode*(d: Document, s: cstring): Node {.importwasmm.}
proc createDocumentFragment*(d: Document): Node {.importwasmm.}
proc setAttribute*(n: Node, k, v: cstring) {.importwasmm.}
proc append*(n, c: Node) {.importwasmm.}
proc append*(n: Node, c: cstring) {.importwasmm.}
proc `textContent=`*(n: Node, c: cstring) {.importwasmp.}
proc classList(d: Node): ClassList {.importwasmp.}
proc add(c: ClassList, cl: cstring) {.importwasmm.}
proc remove(c: ClassList, cl: cstring) {.importwasmm.}

proc onCallback(store, idx, zero1: pointer) {.cdecl.} =
  let store = cast[CallbackStore](store)
  let idx = cast[int32](idx)
  let cb = store.callbacks[idx]
  assert(not cb.isNil, "wafli internal error")
  cb()

proc onValueChange[T](v: JSRef, sub, reactiveImpl: pointer) {.cdecl.} =
  var wr = privateWritableFromImpl[T](cast[RootRef](reactiveImpl))
  let sub = cast[Subscription](sub)
  privateDisable(sub)
  when T is string:
    let o = JSObj(o: v)
    wr %= jsStringToStr(o)
  else:
    wr %= cast[T](v)
  privateEnable(sub)

proc subscribeToAttrChange(n: Node, attr: cstring, isObj: int32, sub, ctx: pointer, cb: proc(v: JSRef, sub, ctx: pointer) {.cdecl.}) {.importwasmraw: """
var o = _nimo[$0], a = _nimsj($1);
o.addEventListener('input', _ => _nime._dviii($5, $2?_nimok(o[a]):o[a], $3, $4))
""".}
proc subscribeToCallback(n: Node, event: cstring, store: pointer, cbIdx: int32, cb: proc(a, b, c: pointer) {.cdecl.}) {.importwasmraw: """
_nimo[$0].addEventListener(_nimsj($1), _ => _nime._dviii($4, $2, $3, 0))
""".}

proc subscribeToCallback*(n: Node, attr: cstring, s: CallbackStore, idx: int) =
  defineDyncall("viii")
  subscribeToCallback(n, attr, cast[pointer](s), idx, onCallback)

proc subscribeToEventPropertyChange*[T](n: Node, key: cstring, ignoreSubscription: Subscription, value: var Writable[T]) =
  defineDyncall("viii")
  subscribeToAttrChange(n, key, int32(T is string), cast[pointer](ignoreSubscription), cast[pointer](privateGetImpl(value)), onValueChange[T])

proc applyFragment*(parent, newFragment: Node, fragId: uint32) {.importwasmraw: """
let
  n = _nimo[$1],
  t = '_wafli',
  a = t + $2,
  A = a + 'e',
  D = document,
  b = D.createElement(t),
  c = D.createElement(t),
  B = D.querySelector(`[${a}]`);
b.setAttribute(a, 1);
n.prepend(b);
c.setAttribute(A, 1);
n.append(c);
if (B) {
  c = D.querySelector(`[${A}]`);
  while ((b = B.nextSibling) != c)
    b.remove();
  c.remove();
  B.replaceWith(n);
} else
  _nimo[$0].append(n)
""".}

proc setClassMultiple*(n: Node, classList: string, predicate: bool) =
  let c = n.classList
  if predicate:
    for cl in classList.split(" "):
      c.add(cl)
  else:
    for cl in classList.split(" "):
      c.remove(cl)
