import wafli
import wafli/[dom, js_utils]
import yasync
import wasmrt

component Head:
  html:
    link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css", rel="stylesheet",
        integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN", crossorigin="anonymous"
    script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/umd/popper.min.js",
        integrity="sha384-I7E8VVD/ismYTF4hNIPjVp/Zjvgyol6VFvRkX/vR+Vc4jQkC+hVqc2pM8ODewa9r", crossorigin="anonymous"
    script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js",
        integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL", crossorigin="anonymous"

proc enableBootstrap*() =
  renderMain(Head, document().head)

proc resumeSleep(cont: pointer) {.cdecl.} =
  let cont = cast[ptr Cont[void]](cont)
  cont.complete()

proc shouldRunAutotest(): bool {.importwasmp: "typeof process!='undefined' && typeof window != 'undefined' && typeof document != 'undegined'".}

template autotest*(body: untyped) =
  {.push hint[DuplicateModuleImport]: off.}
  import yasync
  import wafli/dom
  {.pop.}

  proc sleep(ms: uint32, cont: ptr Cont[void]) {.asyncRaw.} =
    discard setTimeout(ms, resumeSleep, cont)

  proc runAutotest() {.async.} =
    body

  if shouldRunAutotest():
    runAutotest().then() do(e: ref Exception):
      if not e.isNil:
        raise e
      else:
        echo "Autotest complete"
