import macros
import yasync

const debugReactive = not defined(release)

type
  ReactiveImplBase = ref object of RootObj
    refCount: int = 1
    destinations: seq[ReactiveImplBase]
    sources: seq[ReactiveImplBase]
    update: proc(r: ReactiveImplBase) {.gcsafe, nimcall.}
    when debugReactive:
      expression: cstring

  ReactiveImpl[T] = ref object of ReactiveImplBase
    value: T
    updateAux: proc(r: openarray[ReactiveImplBase]): T {.gcsafe.}

  Subscription* = ref object of ReactiveImplBase
    cb: proc() {.gcsafe.}

  Reactive*[T] {.inheritable.} = object
    impl: ReactiveImpl[T]

  Writable*[T] = object of Reactive[T]

proc delElem[T](s: var seq[T], e: T) {.inline.} =
  let i = s.find(e)
  assert(i >= 0)
  s.del(i)

proc release(r: ReactiveImplBase) {.gcsafe, raises: [].}

proc unsubscribeImpl(r: ReactiveImplBase) =
  for s in r.sources:
    delElem(s.destinations, r)
    release(s)
  r.sources = @[]
  r.update = nil

proc release(r: ReactiveImplBase) =
  dec r.refCount
  if r.refCount == 0:
    assert(r.destinations.len == 0)
    unsubscribeImpl(r)

proc `=destroy`*[T](r: Reactive[T]) =
  if r.impl != nil:
    release(r.impl)

proc `=destroy`*[T](r: Writable[T]) =
  if r.impl != nil:
    release(r.impl)

proc `=copy`*[T](a: var Reactive[T], b: Reactive[T]) =
  a.impl = b.impl
  inc a.impl.refCount

proc dup*[T](a: Writable[T]): Writable[T] =
  inc a.impl.refCount
  Writable[T](impl: a.impl)

proc `=copy`*[T](a: var Writable[T], b: Writable[T]) {.error.}
# proc `=copy`*[T](a: var Writable[T], b: Writable[T]) =
#   if a.impl != nil:
#     release(a.impl)
#   if b.impl == nil:
#     a.impl = nil
#   else:
#     a.impl = ReactiveImpl[T](value: b.impl.value)

proc writable*[T](v: T): Writable[T] =
  Writable[T](impl: ReactiveImpl[T](value: v))

proc toReadable*[T](v: Writable[T]): Reactive[T] {.inline.} =
  let impl = v.impl
  inc impl.refCount
  Reactive[T](impl: impl)

proc trigger(r: ReactiveImplBase) {.gcsafe.} =
  let dest = r.destinations
  for d in dest:
    let u = d.update
    if not u.isNil:
      var ok = false
      try:
        u(d)
        ok = true
      except Exception as e:
        when not defined(release):
          when debugReactive:
            echo "Exception caught while updating reactive ", d.expression
          else:
            echo "Exception caught while updating reactive"

          echo e.msg
          echo e.getStackTrace()
      if ok:
        trigger(d)

proc `%=`*[T](r: var Writable[T], v: T) =
  assert(r.impl != nil)
  r.impl.value = v
  trigger(r.impl)

proc add*[T](r: var Writable[seq[T]], v: T) =
  assert(r.impl != nil)
  r.impl.value.add(v)
  trigger(r.impl)

proc `[]=`*[T](r: var Writable[seq[T]], idx: int, v: T) =
  assert(r.impl != nil)
  r.impl.value[idx] = v
  trigger(r.impl)

proc setLen*[T](r: var Writable[seq[T]], sz: int) =
  r.impl.value.setLen(sz)
  trigger(r.impl)

proc subscribeImpl(r: ReactiveImplBase, cb: proc() {.gcsafe.}): Subscription =
  assert(r != nil)
  assert(cb != nil)
  inc r.refCount
  result = Subscription(cb: cb, sources: @[r])
  result.update = proc(r: ReactiveImplBase) =
    let r = cast[Subscription](r)
    if r.refCount != 0:
      let cb = r.cb
      cb()
  assert(result.refCount == 1)
  r.destinations.add(result)

proc subscribe*[T](r: Reactive[T], cb: proc() {.gcsafe.}): Subscription =
  subscribeImpl(r.impl, cb)

proc unsubscribe*(sub: Subscription) {.inline.} =
  unsubscribeImpl(sub)
  sub.cb = nil

proc value*[T](r: Reactive[T]): T =
  assert(r.impl != nil)
  r.impl.value

proc `$`*[T](r: Reactive[T]|Writable[T]): string =
  if unlikely r.impl == nil: "nil"
  else: $r.impl.value

proc updateReal[T](r: ReactiveImplBase) =
  let r = cast[ReactiveImpl[T]](r)
  r.value = r.updateAux(r.sources)

proc derivedAux[T](expression: cstring, sources: openarray[ReactiveImplBase], cb: proc(s: openarray[ReactiveImplBase]): T {.gcsafe.}): Reactive[T] =
  let impl = ReactiveImpl[T](sources: @sources)
  for s in sources:
    s.destinations.add(impl)
    inc s.refCount
  impl.updateAux = cb
  impl.update = updateReal[T]
  when debugReactive:
    impl.expression = expression
  updateReal[T](impl)
  Reactive[T](impl: impl)

proc dumpError(e: ref Exception) =
  echo "Error happened in future"
  echo e.msg
  echo e.getStackTrace

type
  ReactiveImplAsync[T] = ref object of ReactiveImpl[T]
    future: FutureBase

type
  AsyncResult*[T] = object
    value*: T
    loaded*: bool

proc derivedAsyncAux[T](expression: cstring, sources: openarray[ReactiveImplBase], cb: proc(s: openarray[ReactiveImplBase]): Future[T] {.gcsafe.}): Reactive[AsyncResult[T]] =
  let impl = ReactiveImplAsync[AsyncResult[T]](sources: @sources)
  when debugReactive:
    impl.expression = expression
  for s in sources:
    s.destinations.add(impl)
    inc s.refCount
  impl.updateAux = proc(s: openarray[ReactiveImplBase]): AsyncResult[T] =
    let f = cb(s)
    if f.finished:
      if not f.error.isNil:
        dumpError(f.error)
      else:
        return AsyncResult[T](loaded: true, value: f.result)
    else:
      impl.future = f
      f.then() do(v: T, error: ref Exception) {.gcsafe.}:
        if impl.future == f:
          impl.value = AsyncResult[T](loaded: true, value: v)
          trigger(impl)
          if not error.isNil:
            dumpError(error)
          impl.future = nil
  impl.update = updateReal[AsyncResult[T]]
  updateReal[AsyncResult[T]](impl)
  Reactive[AsyncResult[T]](impl: impl)

template findIt[T](v: openarray[T], predicate: untyped): int =
  var res = -1
  for i, it {.inject.} in v:
    if predicate:
      res = i
      break
  res

template getImplBase(r: Reactive|Writable): ReactiveImplBase = r.impl

proc replaceSourcesWithDefault(n: NimNode, res: var seq[NimNode]): NimNode =
  if n.kind == nnkPrefix and n.len == 2 and n[0].kind in {nnkIdent, nnkSym} and $n[0] in ["^", "@^"]:
    let name = n[1]
    var i = findIt(res, it == name)
    if i < 0:
      i = res.len
      res.add(name)
    return newTree(nnkDotExpr, ident("source" & $i), ident"value")
  else:
    for i in 0 ..< n.len:
      n[i] = replaceSourcesWithDefault(n[i], res)
    return n

proc parseDerived(a: NimNode): tuple[sourceImpls, closureBody: NimNode] =
  var sources: seq[NimNode]
  let body = replaceSourcesWithDefault(a, sources)

  let input = ident"reactiveInput_769"
  let closureBody = newNimNode(nnkStmtList)
  let sourceImpls = newNimNode(nnkBracket)
  for i, s in sources:
    let sourceId = ident("source" & $i)
    let typ = newCall("typeof", newCall(bindSym"value", s))
    closureBody.add quote do:
      let `sourceId` = cast[ReactiveImpl[`typ`]](`input`[`i`])
    sourceImpls.add(newCall(bindSym"getImplBase", s))
  closureBody.add(body)
  (sourceImpls, closureBody)

template astToOrigin(n: untyped): cstring =
  when debugReactive:
    cstring(astToStr(n))
  else:
    cstring(nil)

macro derived*(a: untyped): untyped =
  let aCopy = copyNimTree(a)
  let (sourceImpls, closureBody) = parseDerived(a)
  result = quote do:
    derivedAux(astToOrigin(`aCopy`), `sourceImpls`) do(reactiveInput_769 {.inject.}: openarray[ReactiveImplBase]) -> auto {.gcsafe.}:
      `closureBody`

macro derivedAsync*(a: untyped): untyped =
  let aCopy = copyNimTree(a)
  let (sourceImpls, closureBody) = parseDerived(a)
  result = quote do:
    derivedAsyncAux(astToOrigin(`aCopy`), `sourceImpls`) do(reactiveInput_769 {.inject.}: openarray[ReactiveImplBase]) -> auto {.gcsafe.}:
      `closureBody`

converter toValue*[T](r: Reactive[T]): T {.inline.} = r.value

proc privateGetImpl*[T](r: Reactive[T]): RootRef {.inline.} = r.impl
proc privateWritableFromImpl*[T](impl: RootRef): Writable[T] {.inline.} =
  let impl = cast[ReactiveImpl[T]](impl)
  inc impl.refCount
  Writable[T](impl: impl)

proc privateDisable*(s: Subscription) {.inline.} = s.refCount = 0
proc privateEnable*(s: Subscription) {.inline.} = s.refCount = 1
proc privateToWritable*[T](r: Reactive[T]): Writable[T] {.inline.} =
  privateWritableFromImpl[T](r.impl)
