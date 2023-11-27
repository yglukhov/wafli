import wafli
import wafli/dom

component Field:
  var mValue* = writable("some text")
  var name* = writable("name ")
  var someString* = writable("123")

  html:
    di:
      di:
        text derived(^name & ^someString)
      di:
        input value=^^mValue

component *Form:
  var
    someValue = writable(5)
    mSomeText = writable("some text")
    someText* = mSomeText.toReadable()
    mChecked = writable(true)

  proc change(by: int) =
    someValue %= someValue + by

  proc onUp = change(1)
  proc onDown = change(-1)

  proc getSomeString(a: int): string =
    "some string " & $a

  html:
    main:
      Field mValue =^ (^mSomeText & "hi")
      button click=onUp:
        "up"

      input value=^someValue
      button click=onDown:
        text "do" & "wn"

      br
      di id="container"

      text:
        derived("The value is " & $(^someValue))

      br
      input value=^^mSomeText
      br
      input value=^^mSomeText
      br
      input value=^(^mSomeText & " and more")
      br
      input "type"="checkbox", checked=^^mChecked
      input "type"="checkbox", checked=^^mChecked

component TestIf:
  var cond = writable(true)

  proc onClick =
    cond %= not cond

  html:
    button click=onClick:
      "Click"
    di:
      text derived($(^cond))

    if ^cond:
      di:
        "Some text"
    else:
      di: "Some other text"
      di: "And some more"
    di:
      "eof"

component TestFor:
  var arr = writable(@["1", "2", "3"])

  proc onClick =
    arr.add($(arr.len + 1))

  html:
    button click=onClick:
      "click"
    for e in ^arr:
      di class="gi":
        text: e

  cssStr """
    .gi {
      color: #ff0000;
    }
  """











































component Bla:
  html:
    text "blabla"









component Main:
  var a = writable(true)

  proc onClick() =
    echo "blkabla"
    a %= not a

  html:
    button click=onClick:
      "click me"
    Bla

    if ^a:
      ul:
        li: "text1"
        li: "text2"
    else:
      "yooo"
    "hi"


renderMain(Main)






when not defined(wasm):
  echo document().body
