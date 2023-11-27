import ./reactive

type
  CallbackStore* = ref CallbackStoreObj
  CallbackStoreObj = object
    callbacks*: seq[proc()]
    subscriptions*: seq[Subscription]
    children*: seq[CallbackStore]

proc newCallbackStore*(parent: CallbackStore): CallbackStore =
  result = CallbackStore()
  if not parent.isNil:
    parent.children.add(result)

proc clear*(s: CallbackStore) {.gcsafe.} =
  s.callbacks.setLen(0)
  for c in s.children:
    c.clear()
  s.children.setLen(0)
  for ss in s.subscriptions:
    ss.unsubscribe()
  s.subscriptions.setLen(0)
