import ./reactive

type
  CallbackStore* = ref CallbackStoreObj
  CallbackStoreObj = object
    callbacks*: seq[proc()]
    subscriptions*: seq[Subscription]
    unmountCbs*: seq[proc() {.gcsafe.}]
    children*: seq[CallbackStore]

proc newCallbackStore*(): CallbackStore {.inline.} =
  CallbackStore()

proc newCallbackStore*(parent: CallbackStore): CallbackStore =
  result = newCallbackStore()
  parent.children.add(result)

proc clear*(s: CallbackStore) {.gcsafe.} =
  for c in s.children: c.clear()
  for ss in s.subscriptions: ss.unsubscribe()
  for c in s.unmountCbs: c()
  s.callbacks.setLen(0)
  s.children.setLen(0)
  s.subscriptions.setLen(0)
  s.unmountCbs.setLen(0)

proc registerUnmountCb*(s: CallbackStore, cb: proc() {.gcsafe.}) =
  if cb != nil:
    s.unmountCbs.add(cb)
