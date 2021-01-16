<h2>Macro `http` Module
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

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

### HTTP Client

A simple GET request, collecting the full response in memory:

```swift
#!/usr/bin/swift sh
import http // Macro-swift/Macro

http.get("https://zeezide.de") { res in
  console.log("got response:", res)
  
  res.onError { error in
    console.error("error:", error)
  }
  
  res | concat { buffer in
    let s = try? buffer.toString()
    console.log("Response:\n\(s ?? "-")")
  }
}
```

A simple POST request:

```swift
#!/usr/bin/swift sh
import http // Macro-swift/Macro

let options = http.ClientRequestOptions(
  protocol : "https:",
  host     : "jsonplaceholder.typicode.com",
  method   : "POST",
  path     : "/posts"
)

let req = http.request(options) { res in
  console.log("got response:", res)
  
  res.onError { error in
    console.error("error:", error)
  }
  
  res | concat { buffer in
    let s = try? buffer.toString()
    console.log("Response:\n\(s ?? "-")")
  }
}

req.write(
  """
  { "userId": 1,
    "title": "Blubs",
    "body": "Rummss" }
  """
)
req.end()
```
