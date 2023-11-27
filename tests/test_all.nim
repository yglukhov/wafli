import std/[sugar, os, strutils]
import wafli
import wafli/dom

let components = static:
  var r = newSeq[string]()
  for file in walkDir(currentSourcePath.parentDir(), checkDir=true):
    let n = file.path.extractFileName()
    if n.endsWith(".nim") and n.startsWith("t"):
      r.add(n[0 .. ^5])
  r

component Main:
  var selection = writable(components[0])
  let currentTest = derived(^selection & ".html")

  cssStr """
  .b-example-divider {
    width: 100%;
    height: 3rem;
    background-color: rgba(0, 0, 0, .1);
    border: solid rgba(0, 0, 0, .15);
    border-width: 1px 0;
    box-shadow: inset 0 .5em 1.5em rgba(0, 0, 0, .1), inset 0 .125em .5em rgba(0, 0, 0, .15);
  }

  .b-example-vr {
    flex-shrink: 0;
    width: 1.5rem;
    height: 100vh;
  }
  """

  html:
    main class="d-flex flex-nowrap":
      di class="d-flex flex-column flex-shrink-0 p-3 bg-body-tertiary", style="width: 280px;":
        span class="fs-4": "Tests and examples"
        hr
        ul class="nav nav-pills flex-column mb-auto":
          for c in (components):
            li:
              a href="#", class="nav-link active", class("active")=^(^selection == c), click=(() => selection %= c):
                text c
      di class="b-example-divider b-example-vr"
      iframe width="100%", src=^currentTest

renderMain(Main)

component Head:
  html:
    link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css", rel="stylesheet",
        integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN", crossorigin="anonymous"
    script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/umd/popper.min.js",
        integrity="sha384-I7E8VVD/ismYTF4hNIPjVp/Zjvgyol6VFvRkX/vR+Vc4jQkC+hVqc2pM8ODewa9r", crossorigin="anonymous"
    script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js",
        integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL", crossorigin="anonymous"

renderMain(Head, document().head)
