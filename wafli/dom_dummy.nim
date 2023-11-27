import tables, strutils
import ./[reactive, types]

type
  NodeKind = enum
    tag
    text

  Node* = ref object of RootObj
    case kind: NodeKind
    of tag:
      name*: string
      attributes*: Table[string, string]
      children*: seq[Node]
    else:
      discard
    text*: string

  Document* = ref object
    mHead: Node
    mBody: Node

let d = Document(mHead: Node(kind: tag, name: "head"), mBody: Node(kind: tag, name: "body"))
proc document*(): Document = d
proc body*(d: Document): Node = d.mBody
proc head*(d: Document): Node = d.mHead
proc createElement*(d: Document, s: cstring): Node = Node(kind: tag, name: $s)
proc createTextNode*(d: Document, s: cstring): Node = Node(kind: text, text: $s)
proc setAttribute*(n: Node, name, value: cstring) = n.attributes[$name] = $value
proc setProperty*(n: Node, name, value: cstring) = n.setAttribute(name, value)
proc setProperty*(n: Node, name: cstring, value: int) = n.setAttribute($name, $value)
proc append*(n, c: Node) = n.children.add(c)
proc append*(n: Node, text: cstring) = n.children.add(Node(kind: text, text: $text))
proc `textContent=`*(n: Node, c: cstring) =
  if n.kind == text:
    n.text = $c
  else:
    n.children = @[]
    n.append(c)

proc getChildById(n: Node, id: string): Node =
  if n.kind == tag:
    if n.attributes.getOrDefault("id") == id:
      return n
    for c in n.children:
      result = c.getChildById(id)
      if result != nil: return

proc getElementById*(c: Document, id: string): Node =
  c.mBody.getChildById(id)


proc subscribeToCallback*(n: Node, attr: cstring, s: CallbackStore, idx: int) =
  discard
  # defineDyncall("viii")
  # subscribeToCallback(n, attr, cast[pointer](s), idx, onCallback)

proc subscribeToEventPropertyChange*[T](n: Node, key: cstring, ignoreSubscription: Subscription, value: var Writable[T]) =
  discard
  # defineDyncall("viii")
  # subscribeToAttrChange(n, key, int32(T is string), cast[pointer](ignoreSubscription), cast[pointer](privateGetImpl(value)), onValueChange[T])

proc addIndent(res: var string, indent: int) =
  for i in 0 ..< indent:
    res &= ' '

proc prettyAux(n: Node, res: var string, indent: int) =
  addIndent(res, indent)
  case n.kind
  of text:
    res &= n.text
    res &= '\n'
  of tag:
    res &= '<'
    res &= n.name
    for k, v in n.attributes:
      res &= ' '
      res &= k
      res &= "=\""
      res &= v
      res &= "\""
    if n.children.len == 0:
      res &= " />\n"
    else:
      res &= ">\n"
      for c in n.children:
        prettyAux(c, res, indent + 2)
      addIndent(res, indent)
      res &= "</"
      res &= n.name
      res &= ">\n"

proc `$`*(n: Node): string =
  prettyAux(n, result, 0)

proc classList(n: Node): seq[string] =
  n.attributes["class"].split(" ")

proc setClassMultiple*(n: Node, classList: string, predicate: bool) =
  var c = n.classList
  if predicate:
    for cl in classList.split(" "):
      if cl notin c:
        c.add(cl)
  else:
    for cl in classList.split(" "):
      let i = c.find(cl)
      if i >= 0:
        c.delete(i)
  n.attributes["class"] = c.join(" ")
