#  Macro `http` Module

An HTTP module modelled after the builtin Node
[http module](https://nodejs.org/dist/latest-v7.x/docs/api/http.html).
In applications you probably want to use the Connect or Express module instead.

### HTTP server

Example:

```swift
import http

http.createServer { req, res in 
  res.writeHead(200, [ "Content-Type": "text/html" ])
  res.end("<h1>Hello World</h1>")
}
.listen(1337)
```
