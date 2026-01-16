import wafli
import wafli/[reactive, dom]
import ./common

proc log1(a: string) =
  echo "LOG ", a
  let d = document()
  let l = d.getElementById("log")
  if not l.isNil:
    l.append(a)
    l.append(d.createElement("br"))

var lastMountedComp = 0
var lastUnmountedComp = 0

component Comp1:
  log1 "mount Comp1"
  lastMountedComp = 1
  unmount:
    log1 "unmount Comp1"
    lastUnmountedComp = 1
  html:
    "comp1"

component Comp2:
  log1 "mount Comp2"
  lastMountedComp = 2
  unmount:
    log1 "unmount Comp2"
    lastUnmountedComp = 2
  html:
    "comp2"

component *Form:
  var chk* = writable(false)

  html:
    input checked=^^chk, "type"="checkbox"
    if ^chk:
      Comp1
    else:
      Comp2
    di id="log"

renderMain(Form)

autotest:
  let checkbox = document().querySelector("input[type='checkbox']")
  doAssert(lastMountedComp == 2)
  doAssert(lastUnmountedComp == 0)
  checkbox.click()
  doAssert(lastMountedComp == 1)
  doAssert(lastUnmountedComp == 2)
  checkbox.click()
  doAssert(lastMountedComp == 2)
  doAssert(lastUnmountedComp == 1)
