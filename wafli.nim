import macros, strutils
import wafli/[types, reactive, dom]
export reactive

type
  VarDef = tuple
    isLet: bool
    name: NimNode # nnkIdent

  Component* = ref object of RootObj
    mRenderHtml*: proc(cbStore: CallbackStore, root: Node, document: Document) {.gcsafe.}
    mUnmount*: proc() {.gcsafe.}

proc setProperty(n: Node, k: cstring, v: bool) {.inline.} =
  setProperty(n, k, int32(v))

proc setAttribute(n: Node, attr, v: cstring, ctx: CallbackStore) {.inline.} =
  setAttribute(n, attr, v)

proc setAttribute(n: Node, attr: cstring, cb: proc(), ctx: CallbackStore) =
  assert(not cb.isNil)
  let idx = ctx.callbacks.len
  ctx.callbacks.add(cb)
  subscribeToCallback(n, attr, ctx, idx)

proc setReactiveProperty[T](n: Node, name: cstring, value: Reactive[T], ctx: CallbackStore) =
  ctx.subscriptions.add value.subscribe() do() {.gcsafe.}:
    setProperty(n, name, value.value)
  setProperty(n, name, value.value)

proc setReactiveWritableProperty[T](n: Node, tag, key: static[string], value: var Writable[T], ctx: CallbackStore) =
  let r = value.toReadable()
  let s = value.subscribe() do() {.gcsafe.}:
    setProperty(n, key, r.value)
  setProperty(n, key, r.value)
  ctx.subscriptions.add(s)
  when tag in ["input", "select", "textarea"] and key in ["value", "checked"]:
    subscribeToEventPropertyChange(n, key, s, value)
  else:
    {.error: "Don't know how to bind to " & tag & "." & key.}

proc setReactiveClass(n: Node, cls: string, predicate: Reactive[bool], ctx: CallbackStore) =
  ctx.subscriptions.add predicate.subscribe() do() {.gcsafe.}:
    setClassMultiple(n, cls, predicate)
  setClassMultiple(n, cls, predicate)

proc append(n: Node, v: cstring, ctx: CallbackStore, document: Document) {.inline.} =
  assert(not n.isNil)
  n.append(v)

proc append(n, v: Node, ctx: CallbackStore, document: Document) {.inline.} =
  assert(not n.isNil)
  n.append(v)

proc append(n: Node, value: Reactive[string], ctx: CallbackStore, document: Document) =
  let nv = document.createTextNode(value.value)
  n.append(nv)
  ctx.subscriptions.add value.subscribe() do() {.gcsafe.}:
    nv.textContent = value.value

proc parseName(name: NimNode): tuple[name: NimNode, isPublic: bool] =
  const nameKinds = {nnkIdent, nnkSym}
  case name.kind
  of nameKinds:
    return (name, false)
  of nnkPrefix, nnkPostfix:
    name.expectLen(2)
    assert($name[0] == "*")
    name[1].expectKind(nameKinds)
    return (name[1], true)
  else:
    echo repr name
    assert(false, "Unexpected name")

proc collectVars(body: NimNode, res: var seq[VarDef]) =
  for n in body:
    if n.kind in {nnkVarSection, nnkLetSection}:
      for c in n:
        if c.kind == nnkIdentDefs:
          let (name, isPublic) = parseName(c[0])
          if isPublic:
            c[0] = name
            res.add((n.kind == nnkLetSection, name))

proc replaceVars(body: NimNode): NimNode =
  result = newNimNode(nnkStmtList)
  for n in body:
    if n.kind in {nnkVarSection, nnkLetSection}:
      for c in n:
        var processed = false
        if c.kind == nnkIdentDefs:
          let (name, isPublic) = parseName(c[0])
          if isPublic:
            result.add quote do:
              template `name`: auto = theEnv.`name`
            let val = c[2]
            if val.kind != nnkEmpty:
              result.add quote do:
                `name` = `val`
            processed = true
        if not processed:
          result.add(newTree(n.kind, c))
    else:
      result.add(n)

proc starName(name: NimNode, isPublic: bool): NimNode =
  if isPublic:
    newTree(nnkPostfix, ident "*", name)
  else:
    name

proc isComponentName(name: NimNode): bool =
  name.kind == nnkIdent and ($name)[0].isUpperAscii

proc fixupTagName(name: string): string =
  case name
  of "di", "tdiv": "div"
  else: name

proc newFragId(): uint32 =
  var r {.global.}: uint32
  inc r
  return r

proc derive(c: NimNode): NimNode =
  # if c is ident, return derived(^c)
  # else: return derived(c)
  if c.kind in {nnkIdent, nnkSym}:
    return quote do:
      derived(^`c`)
  else:
    return quote do:
      derived(`c`)

proc processHtmlElements(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode)

proc processIfStmt(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  let subscriptions = newNimNode(nnkStmtList)
  let newIf = newTree(nnkIfStmt)

  inc idCounter
  let prcId = ident("prc" & $idCounter)
  let fragmentId = ident("fragment" & $idCounter)
  let componentId = ident("cbstore" & $idCounter)
  let fragId = ident("frag" & $idCounter)

  for branch in n:
    let body = newNimNode(nnkStmtList)
    processHtmlElements(branch[^1], fragmentId, idCounter, body, componentId, document)
    case branch.kind
    of nnkElifBranch:
      inc idCounter
      let condId = ident("cond" & $idCounter)
      let cond = derive(branch[0])
      res.add quote do:
        let `condId` = `cond`

      subscriptions.add quote do:
        `component`.subscriptions.add `condId`.subscribe(`prcId`)

      newIf.add(newTree(nnkElifBranch, condId, body))
    of nnkElse:
      newIf.add(newTree(nnkElse, body))
    else:
      echo treeRepr(branch)
      assert(false, "Unexpected node")

  res.add quote do:
    let `componentId` = newCallbackStore(`component`)
    let `fragId` = newFragId()
    proc `prcId`() {.gcsafe.} =
      `componentId`.clear()
      let `fragmentId` = `document`.createDocumentFragment()
      `newIf`
      applyFragment(`parentId`, `fragmentId`, `fragId`)
    `prcId`()

    `subscriptions`

proc processCaseStmt(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  inc idCounter
  let prcId = ident("prc" & $idCounter)
  let fragmentId = ident("fragment" & $idCounter)
  let componentId = ident("cbstore" & $idCounter)
  let condId = ident("cond" & $idCounter)
  let fragId = ident("frag" & $idCounter)
  let cond = derive(n[0])
  res.add quote do:
    let `condId` = `cond`

  let newCase = newTree(nnkCaseStmt, newCall(bindSym"value", condId))

  for i in 1 ..< n.len:
    let branch = n[i]
    let body = newNimNode(nnkStmtList)
    processHtmlElements(branch[^1], fragmentId, idCounter, body, componentId, document)
    case branch.kind
    of nnkOfBranch:
      newCase.add(newTree(nnkOfBranch, branch[0], body))
    of nnkElse:
      newCase.add(newTree(nnkElse, body))
    else:
      echo treeRepr(branch)
      assert(false, "Unexpected node")

  res.add quote do:
    let `componentId` = newCallbackStore(`component`)
    let `fragId` = newFragId()
    proc `prcId`() {.gcsafe.} =
      `componentId`.clear()
      let `fragmentId` = `document`.createDocumentFragment()
      `newCase`
      applyFragment(`parentId`, `fragmentId`, `fragId`)
    `prcId`()
    `component`.subscriptions.add `condId`.subscribe(`prcId`)

proc makeCaptureForForStmt(n, content: NimNode): NimNode =
  let prc = newProc(procType = nnkLambda)
  let prms = prc.params
  let call = newCall(prc)
  for i in 0 ..< n.len - 2:
    prms.add(newIdentDefs(n[i], newCall("typeof", n[i])))
    call.add(n[i])
  prc.body = content
  result = call

proc processForStmt(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  inc idCounter
  let prcId = ident("prc" & $idCounter)
  let fragmentId = ident("fragment" & $idCounter)
  let componentId = ident("cbstore" & $idCounter)
  let condId = ident("cond" & $idCounter)
  let fragId = ident("frag" & $idCounter)
  let cond = derive(n[^2])
  res.add quote do:
    let `condId` = `cond`

  let newFor = newTree(nnkForStmt)
  for i in 0 ..< n.len - 2:
    newFor.add(n[i])
  newFor.add(newCall(bindSym"value", condId))

  # for i in 1 ..< n.len:
  let body = newNimNode(nnkStmtList)
  processHtmlElements(n[^1], fragmentId, idCounter, body, componentId, document)
  # newFor.add(body)
  newFor.add(makeCaptureForForStmt(n, body))

  res.add quote do:
    let `componentId` = newCallbackStore(`component`)
    let `fragId` = newFragId()
    proc `prcId`() {.gcsafe.} =
      `componentId`.clear()
      let `fragmentId` = `document`.createDocumentFragment()
      `newFor`
      applyFragment(`parentId`, `fragmentId`, `fragId`)
    `prcId`()
    `component`.subscriptions.add `condId`.subscribe(`prcId`)

proc processWhenStmt(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  for c in n:
    var s = newNimNode(nnkStmtList)
    processHtmlElements(c[^1], parentId, idCounter, s, component, document)
    c[^1] = s
  res.add(n)

type
  AttrKind = enum
    setOnce
    bindRead
    bindWrite

  AttrDesc = tuple
    kind: AttrKind
    name: string
    value: NimNode

proc parseNodeAttributes(n: NimNode): seq[AttrDesc] =
  if n.kind in {nnkCommand, nnkCall}:
    for i in 1 ..< n.len:
      let attr = n[i]
      if i == n.len - 1 and attr.kind == nnkStmtList:
        discard
      else:
        if attr.kind == nnkInfix and $attr[0] == "=^":
          var v = attr[2]
          if v.kind notin {nnkIdent, nnkSym}:
            v = newCall(bindSym"derived", v)
          result.add((bindRead, $attr[1], v))
        elif attr.kind == nnkInfix and $attr[0] == "=^^":
          result.add((bindWrite, $attr[1], attr[2]))
        else:
          attr.expectKind(nnkExprEqExpr)
          result.add((setOnce, $attr[0], attr[1]))

proc bindAttributeRead[T](a: var Writable[T], b: Reactive[T], cbStore: CallbackStore) =
  a %= b.value
  let r = a.toReadable()
  cbStore.subscriptions.add b.subscribe() do() {.gcsafe.}:
    var w = privateToWritable(r)
    w %= b.value

proc bindAttributeWrite[T](a, b: var Writable[T], cbStore: CallbackStore) =
  a %= b.value

  var sa, sb: Subscription
  let ra = a.toReadable()
  let rb = b.toReadable()

  sa = a.subscribe() do() {.gcsafe.}:
    sa.privateDisable()
    var w = privateToWritable(rb)
    w %= ra.value
    sa.privateEnable()

  sb = b.subscribe() do() {.gcsafe.}:
    sb.privateDisable()
    var w = privateToWritable(ra)
    w %= rb.value
    sb.privateEnable()

  cbStore.subscriptions.add(sa)
  cbStore.subscriptions.add(sb)

proc bindAttributeWrite[T](a: Reactive[T], b: var Writable[T], cbStore: CallbackStore) =
  b %= a.value

  let rb = b.toReadable()

  let sa = a.subscribe() do() {.gcsafe.}:
    var w = privateToWritable(rb)
    w %= a.value

  cbStore.subscriptions.add(sa)

proc processSubcomponent(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  let name = case n.kind
  of {nnkCommand, nnkCall}: n[0]
  of {nnkIdent, nnkSym}: n
  else:
    assert(false)
    nil
  inc idCounter
  let id = ident($name & $idCounter)
  let attrs = parseNodeAttributes(n)
  res.add quote do:
    var `id` = `name`()
    registerUnmountCb(`component`, `id`.mUnmount)

  for a in attrs:
    let attrName = ident(a.name)
    let attrValue = a.value
    case a.kind
    of setOnce:
      res.add quote do:
        `id`.`attrName` %= `attrValue`
    of bindRead:
      res.add quote do:
        bindAttributeRead(`id`.`attrName`, `attrValue`, `component`)
    of bindWrite:
      res.add quote do:
        bindAttributeWrite(`id`.`attrName`, `attrValue`, `component`)

  res.add quote do:
    `id`.renderHtml(`component`, `parentId`, `document`)

proc processTextElement(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  n.expectLen(2)
  let rest = n[1]
  if rest.kind == nnkStmtList:
    for cc in rest:
      res.add quote do:
        append(`parentId`, `cc`, `component`, `document`)
  else:
    res.add quote do:
      append(`parentId`, `rest`, `component`, `document`)

proc processHtmlElements(n, parentId: NimNode, idCounter: var int, res, component, document: NimNode) =
  for c in n:
    case c.kind
    of {nnkCommand, nnkCall}:
      let tagName = fixupTagName($c[0])
      if tagName == "text":
        processTextElement(c, parentId, idCounter, res, component, document)
      elif isComponentName(c[0]):
        processSubComponent(c, parentId, idCounter, res, component, document)
      else:
        inc idCounter
        let elemId = ident(tagName & $idCounter)
        res.add quote do:
          let `elemId` = `document`.createElement(`tagName`)
        for i in 1 ..< c.len:
          let attr = c[i]
          if i == c.len - 1 and attr.kind == nnkStmtList:
            processHtmlElements(attr, elemId, idCounter, res, component, document)
          elif attr.kind == nnkInfix and $attr[0] == "=^":
            let attrName = attr[1]
            case attrName.kind
            of nnkIdent, nnkStrLit:
              let name = $attrName
              let value = attr[2]
              if value.kind in {nnkIdent, nnkSym}:
                res.add quote do:
                  setReactiveProperty(`elemId`, `name`, `value`, `component`)
              else:
                res.add quote do:
                  setReactiveProperty(`elemId`, `name`, derived(`value`), `component`)
            of nnkCall:
              if $attrName[0] != "class":
                raise newException(ValueError, "Unexpected attribute " & repr(attrName))
              let cls = attrName[1]
              let value = derive(attr[2])
              res.add quote do:
                setReactiveClass(`elemId`, `cls`, `value`, `component`)
            else:
              assert(false, "Unexpected node kind")
          elif attr.kind == nnkInfix and $attr[0] == "=^^":
            let attrName = attr[1]
            attrName.expectKind({nnkIdent, nnkStrLit})
            let name = $attrName
            let value = attr[2]
            res.add quote do:
              setReactiveWritableProperty(`elemId`, `tagName`, `name`, `value`, `component`)
          else:
            attr.expectKind(nnkExprEqExpr)
            let attrName = attr[0]
            attrName.expectKind({nnkIdent, nnkStrLit})
            let name = $attrName
            let value = attr[1]
            if name == "onInit":
              res.add quote do:
                `value`(`elemId`)
            else:
              res.add quote do:
                setAttribute(`elemId`, `name`, `value`, `component`)
        res.add quote do:
          append(`parentId`, `elemId`, `component`, `document`)
    of {nnkIdent, nnkSym}:
      if isComponentName(c):
        processSubComponent(c, parentId, idCounter, res, component, document)
      else:
        let tagName = fixupTagName($c)
        res.add quote do:
          append(`parentId`, `document`.createElement(`tagName`), `component`, `document`)
    of nnkStrLit:
      res.add quote do:
        append(`parentId`, `c`)
    of nnkIfStmt:
      processIfStmt(c, parentId, idCounter, res, component, document)
    of nnkCaseStmt:
      processCaseStmt(c, parentId, idCounter, res, component, document)
    of nnkForStmt:
      processForStmt(c, parentId, idCounter, res, component, document)
    of nnkDiscardStmt:
      discard
    of nnkWhenStmt:
      processWhenStmt(c, parentId, idCounter, res, component, document)
    else:
      echo treeRepr c
      assert(false, "unknown html node")

proc processHtmlAux(b: NimNode): NimNode =
  var idCounter = 0
  let renderCode = newNimNode(nnkStmtList)
  let root = ident"root"
  let document = ident"document"
  let component = ident"component"

  processHtmlElements(b[1], root, idCounter, renderCode, component, document)

  result = quote do:
    theEnv.mRenderHtml = proc(`component`: CallbackStore, `root`: Node, `document`: Document) {.gcsafe.} =
      `renderCode`

var allCss {.compileTime.} = "_wafli{display: none;}"

proc processCssAux(b: NimNode): NimNode =
  result = newEmptyNode()
  let css = $b[1]
  allCss &= css
  allCss &= "\n"

proc processHtml(b: NimNode): NimNode =
  result = b
  for i in 0 ..< b.len:
    if b[i].kind == nnkCall and b[i][0].kind == nnkIdent and $b[i][0] == "html":
      b[i] = processHtmlAux(b[i])
      # return
    elif b[i].kind in { nnkCall, nnkCommand } and b[i][0].kind == nnkIdent and $b[i][0] == "cssStr":
      b[i] = processCssAux(b[i])

  # error("html not defined")

proc makeEnvType(name: NimNode, vars: seq[VarDef]): NimNode =
  let recList = newNimNode(nnkRecList)
  for v in vars:
    let name = v.name
    let typ = newCall("typeof", name)
    recList.add(newIdentDefs(starName(name, true), typ))
  result = newTree(nnkTypeSection,
                   newTree(nnkTypeDef,
                           name,
                           newEmptyNode(),
                           newTree(nnkRefTy,
                                   newTree(nnkObjectTy,
                                           newEmptyNode(),
                                           newTree(nnkOfInherit, bindSym"Component"),
                                           recList))))

proc makeExtractEnvTypeFunc(name: NimNode, body: NimNode, vars: seq[VarDef]): NimNode =
  let typ = makeEnvType(name, vars)

  result = quote do:
    proc getBodyTypeFunc(): auto =
      template html(b: untyped) {.used, inject.} = discard
      template cssStr(b: untyped) {.used, inject.} = discard
      template unmount(b: untyped) {.used, inject.} = discard
      {.push used.}
      `body`
      {.pop.}
      `typ`
      return `name`()

proc processComponent(name, body: NimNode): NimNode =
  var vars: seq[VarDef]
  let extractorBody = copyNimTree(body)
  collectVars(extractorBody, vars)
  let (name, isComponentPublic) = parseName(name)

  result = newProc(starName(name, isComponentPublic))
  let args = result.params
  args[0] = ident"auto"

  let procBody = newNimNode(nnkStmtList)

  let extractTypeFunc = makeExtractEnvTypeFunc(name, extractorBody, vars)
  let body = processHtml(replaceVars(body))

  let theEnv = ident"theEnv"

  procBody.add quote do:
    `extractTypeFunc`
    let `theEnv` = typeof(getBodyTypeFunc())()
    template unmount(code: untyped) {.used.} =
      `theEnv`.mUnmount = proc() {.gcsafe.} =
        code
    `body`
    return `theEnv`

  result.body = procBody

  # echo repr result

macro component*(name, body: untyped): untyped =
  result = processComponent(name, body)

proc writeCss(css: string) =
  let d = document()
  let style = d.createElement("style")
  style.textContent = css
  d.head.append(style)


var mainCallbackStore: CallbackStore


proc renderHtml*(c: Component, store: CallbackStore, rootNode: Node, document: Document) =
  let rnd = c.mRenderHtml
  if not rnd.isNil:
    rnd(store, rootNode, document)

template renderMain*(c: untyped, rootNode: Node) =
  block:
    writeCss(static(allCss))
    if mainCallbackStore.isNil:
      mainCallbackStore = newCallbackStore()
    var comp = c()
    renderHtml(comp, mainCallbackStore, rootNode, document())

template renderMain*(c: untyped) =
  renderMain(c, document().body)
