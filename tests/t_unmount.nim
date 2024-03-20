import wafli
import wafli/[reactive, dom]

proc log1(a: string) =
  echo "LOG ", a
  let d = document()
  let l = d.getElementById("log")
  if not l.isNil:
    l.append(a)
    l.append(d.createElement("br"))

component Comp1:
  log1 "mount Comp1"
  unmount:
    log1 "unmount Comp1"
  html:
    "comp1"

component Comp2:
  log1 "mount Comp2"
  unmount:
    log1 "unmount Comp2"
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
