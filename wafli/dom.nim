import std/[tables, strutils]
import wasmrt
import ./[reactive, types, js_utils]

export setProperty, isNil

type
  Node* {.externref.} = object of JSObject
  Document* {.externref.} = object of JSObject

  ClassList {.externref.} = object of JSObject

proc document*(): Document {.importwasmp.}
proc body*(d: Document): Node {.importwasmp.}
proc head*(d: Document): Node {.importwasmp.}
proc documentElement*(d: Document): Node {.importwasmp.}
proc getElementById*(d: Document, id: cstring): Node {.importwasmm.}
proc createElement*(d: Document, s: cstring): Node {.importwasmm.}
proc createTextNode*(d: Document, s: cstring): Node {.importwasmm.}
proc createDocumentFragment*(d: Document): Node {.importwasmm.}
proc querySelector*(d: Document, s: string): Node {.importwasmm.}
proc setAttribute*(n: Node, k, v: cstring) {.importwasmm.}
proc append*(n, c: Node) {.importwasmm.}
proc append*(n: Node, c: cstring) {.importwasmm.}
proc `textContent=`*(n: Node, c: cstring) {.importwasmp.}
proc classList(d: Node): ClassList {.importwasmp.}
proc add(c: ClassList, cl: cstring) {.importwasmm.}
proc remove(c: ClassList, cl: cstring) {.importwasmm.}


proc newMouseEvent*(name: string, bubbles, canelable: bool): JSObject {.importwasmexpr: "new window.MouseEvent($0, {bubbles: !!$1, cancelable: !!$2, view: window})".}
proc dispatchEvent*(n: Node, e: JSObject) {.importwasmm.}
proc innerHTML*(d: Node): string {.importwasmp.}
proc value*(d: Node): string {.importwasmp.}
proc click*(d: Node) =
  let clickEv = newMouseEvent("click", true, true)
  d.dispatchEvent(clickEv)


proc onCallback(store, idx: pointer) {.cdecl.} =
  let store = cast[CallbackStore](store)
  let idx = cast[int32](idx)
  let cb = store.callbacks[idx]
  assert(not cb.isNil, "wafli internal error")
  cb()

proc jsToInt(j: JSObject): int32 {.importwasmexpr: "$0".}

proc onValueChange[T](v: JSObject, sub, reactiveImpl: pointer) {.cdecl.} =
  var wr = privateWritableFromImpl[T](cast[RootRef](reactiveImpl))
  let sub = cast[Subscription](sub)
  privateDisable(sub)
  when T is string:
    wr %= v.JSString
  elif T is bool:
    wr %= bool(jsToInt(v))
  elif T is int|int32:
    wr %= T(jsToInt(v))
  else:
    {.error: "Unexpected type " & $T.}
  privateEnable(sub)

proc subscribeToAttrChange(n: Node, attr: cstring, sub, ctx: pointer, cb: proc(v: JSObject, sub, ctx: pointer) {.cdecl.}) {.importwasmraw: """
$0.addEventListener('input', _ => $4($0[$1], $2, $3))
""".}
proc subscribeToCallback(n: Node, event: cstring, store: pointer, cbIdx: int32, cb: proc(a, b: pointer) {.cdecl.}) {.importwasmraw: """
$0.addEventListener($1, _ => $4($2, $3))
""".}

proc subscribeToCallback*(n: Node, attr: cstring, s: CallbackStore, idx: int) =
  subscribeToCallback(n, attr, cast[pointer](s), idx, onCallback)

proc subscribeToEventPropertyChange*[T](n: Node, key: cstring, ignoreSubscription: Subscription, value: var Writable[T]) =
  subscribeToAttrChange(n, key, cast[pointer](ignoreSubscription), cast[pointer](privateGetImpl(value)), onValueChange[T])

proc applyFragment*(parent, newFragment: Node, fragId: uint32) {.importwasmraw: """
let
  t = '_wafli',
  a = t + $2,
  A = a + 'e',
  D = document,
  b = D.createElement(t),
  c = D.createElement(t),
  B = D.querySelector(`[${a}]`);
b.setAttribute(a, 1);
$1.prepend(b);
c.setAttribute(A, 1);
$1.append(c);
if (B) {
  c = D.querySelector(`[${A}]`);
  while ((b = B.nextSibling) != c)
    b.remove();
  c.remove();
  B.replaceWith($1)
} else
  $0.append($1)
""".}

proc setClassMultiple*(n: Node, classList: string, predicate: bool) =
  let c = n.classList
  if predicate:
    for cl in classList.split(" "):
      c.add(cl)
  else:
    for cl in classList.split(" "):
      c.remove(cl)
