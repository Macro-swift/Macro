# Macro

Macro is the package you may usually want to import.
It imports ALL Macro submodules and re-exports their functions.

Note that doing a `import Macro` still results in namespaced
functions, e.g. the `http` prefix is necessary:

```swift
import Macro

http.createServer { req, res in
  ...
}
```

You can still import the specific module and get a top-level import:
```
import http`

createServer { req, res in }
  ...
}
```

If you don't want to import all Macro modules, you can also just import
individual modules like `fs` (e.g. w/o HTTP/NIOHTTP1).
