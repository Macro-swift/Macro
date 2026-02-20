<h2>Macro `ws` WebSocket Module
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

This is designed after the
[`ws`](https://github.com/websockets/ws)
de facto WebSocket library for Node.

[WebSocket](https://en.wikipedia.org/wiki/WebSocket)'s are part of 
`Macro` (vs `MacroExpress`), because
[SwiftNIO](https://github.com/apple/swift-nio)
already carries the protocol implementation.
This is just a thin wrapper around it.

### Server Example

```swift
#!/usr/bin/swift sh
import Macro // @Macro-swift
import ws    // Macro-swift/Macro

let wss = WebSocket.Server(port: 8080)
wss.onConnection { ws in
  ws.onMessage { message in
    console.log("Received:", message)
  }
  ws.send("Hello!")
}
```
