import std/strutils
import wafli
import ./common

enableBootstrap()

component Main:
  var counterValue = writable "1"
  proc parseValue(): int =
    try: parseInt(counterValue) except: 0

  proc onInc =
    counterValue %= $(parseValue() + 1)

  proc onDec =
    counterValue %= $(parseValue() - 1)

  html:
    di class="container d-flex align-items-center flex-column justify-content-center", style="height: 600px;":
      h1:
        "Counter"
      di class="input-group mb-3":
        di class="input-group-prepend":
          button class="btn btn-outline-secondary", click=onDec, id="dec_btn":
            "dec"
        input class="form-control", placeholder="Enter some int value", value=^^counterValue
        di class="input-group-append":
          button class="btn btn-outline-secondary", click=onInc, id="inc_btn":
            "inc"
      h2:
        "The value is "
        text counterValue

renderMain(Main)

autotest:
  let input = document().querySelector("input")
  let incButton = document().getElementById("inc_btn")
  let decButton = document().getElementById("dec_btn")
  doAssert(input.value == "1")
  incButton.click()
  doAssert(input.value == "2")
  incButton.click()
  doAssert(input.value == "3")
  decButton.click()
  doAssert(input.value == "2")
  decButton.click()
  doAssert(input.value == "1")
