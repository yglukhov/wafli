import std/strutils
import wafli

component Main:
  var counterValue = writable "1"
  proc parseValue(): int =
    try: parseInt(counterValue) except: 0

  proc onInc =
    counterValue %= $(parseInt(counterValue) + 1)

  proc onDec =
    counterValue %= $(parseInt(counterValue) - 1)

  html:
    center:
      di:
        input value=^^counterValue, placeholder="Enter some int value"
      di:
        button click=onInc:
          "inc"
        button click=onDec:
          "dec"
      di:
        "The value is "
        text counterValue

renderMain(Main)
