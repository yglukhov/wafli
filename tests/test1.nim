import wafli/reactive
# import wafli/[dom, types]
# import wasmrt
# import wasmrt/printf

# proc c_fprintf(file: pointer, fmt: cstring): cint {.varargs, importc: "fprintf".}
# echo "Calling printf now"
# discard c_fprintf(nil, "hello %\n", "world!")

# proc debugger() {.importwasmraw: "debugger".}

# type Dummy = object
#   a: int

# var counter = 0

# proc `=destroy`(d: var Dummy) =
#   if d.a != 0:
#     echo "Destroying dummy ", d.a
#     # debugger()
#     d.a = 0

# proc `=copy`(d: var Dummy, a: Dummy) =
#   inc counter
#   echo "Destroying dummy ", d.a, " and copying ", a.a, " to ", counter
#   d.a = counter

# proc newDummy(): Dummy =
#   inc counter
#   Dummy(a: counter)

# type FooBar = ref object of RootObj

# type FooBar2 = ref object of FooBar
#   cl: proc()

# proc mkClos(a: proc()): FooBar =
#   FooBar2(cl: a)

proc testfoo() =
  # let d = newDummy()
  # let i = ReactiveImpl(value: "bla")
  var wr = writable("bla")
  # let f = mkClos() do():
  #   echo wr
  #   echo d.a

  # let r = derived(^wr & $d.a)

testfoo()
GC_fullCollect()

# type FormComponent = ref object of Component

# proc Form*(): FormComponent =
#   let theEnv = FormComponent()

#   var page = writable("bla")
#   var d = newDummy()
#   theEnv.mRenderHtml = proc (component: CallbackStore; root: Node;
#                              document: Document) {.gcsafe.} =
#     var div1 = document.createElement("div")
#     let cond3 = derived(^page == "bla")
#     let cbstore2 = newCallbackStore(component)
#     let frag2 = 0'u32 #newFragId()
#     proc prc2() {.gcsafe.} =
#       # echo "WILL CLEAR: ", cond3.impl.expression
#       cbstore2.clear()
#       var fragment2 = document.createDocumentFragment()
#       if true: #cond3:
#         append(fragment2, "SUB Page 1: ")
#         # append(fragment2, $d.a)
#       applyFragment(div1, fragment2, frag2)

#     prc2()
#     # component.subscriptions.add cond3.subscribe(prc2)
#     # append(root, div1, component, document)
#   return theEnv


# # component *Form:
# #   var page = writable("bla")
# #   var d = newDummy()

# #   html:
# #     di:
# #       if ^page == "bla":
# #         "SUB Page 1: "
# #         text $d.a

# var page = writable(0)

# component Select:
#   html:
#     button click=(proc() = echo "PAGE 0"; page %= 0):
#       "SUPER Page 1"
#     button click=(proc() = echo "PAGE 1"; page %= 1; GC_fullCollect()):
#       "SUPER Page 2"

#     di:
#       if ^page == 0:
#         "SUPER Page 1"
#         Form
#       else:
#         "SUPER Page 2"


# renderMain(Select)
# page %= 1
# # proc findTracedCell() {.importc.}
# # echo "TRACED:"
# # findTracedCell()

# echo "collect"
# GC_fullCollect()
# # echo document().body
