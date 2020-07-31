#  Macro `http` Module

An HTTP module modelled after the builtin Node
[http module](https://nodejs.org/dist/latest-v7.x/docs/api/http.html).
In applications you probably want to use the Connect or Express module instead.

The HTTP server is backed by SwiftNIO 2.

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

### AWS Lambda API Gateway Support

Macro also provides a `lambda.createServer` which works with
AWS Lambda functions addressed using the 
AWS [API Gateway](https://aws.amazon.com/api-gateway/) V2.

Example:

```swift
let server = lambda.createServer { req, res in
  res.writeHead(200, [ "Content-Type": "text/html" ])
  res.end("<h1>Hello World</h1>")
}
server.run()
```

Checkout the [readme](Lambda/README.md) in the [Lambda](Lambda/) folder.
