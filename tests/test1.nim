import wafli
import wafli/reactive
import wafli/dom_dummy

component *Form:
  var
    foo* = writable(5)
    yo* = derived(^foo + 5)
    mSomeText = writable("")
    someText* = mSomeText.toReadable()
    someString* = "hello"

  html:
    ul:
      li: "hi"
      li: "bye"
    input value=^^mSomeText
    di id="hi", class="asdfg":
      "some text"
      "some more text"
      text someString
    di:
      "some"
    # Filter

renderMain(Form)
echo document().body
