The tests are run in nodejs, using jsdom package to simulate dom api in node.

https://github.com/jsdom/jsdom

Command to create a single js file from jsdom package:
```
npx esbuild jsdom --bundle --platform=node --external:canvas --define:require.resolve=undefined --outfile=tests/jsdom-bundle.js
```

