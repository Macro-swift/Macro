<h2>Macro
  <img src="http://zeezide.com/img/macro/MacroExpressIcon128.png"
       align="right" width="100" height="100" />
</h2>

A small, unopinionated "don't get into my way" / "I don't wanna `wait`" 
asynchronous web framework for Swift.
With a strong focus on replicating the Node APIs in Swift.
But in a typesafe, and fast way.

Macro is a more capable variant of 
[µExpress](https://github.com/NozeIO/MicroExpress).
The goal is still to keep a small core, but add some 
[Noze.io](http://noze.io)
modules and concepts.

Eventually it might evolve into Noze.io v2 (once backpressure enabled streams
are fully working).

The companion [MacroExpress](https://github.com/Macro-swift/MacroExpress)
package adds Express.js-like middleware processing and functions, as well
as templates.
[MacroLambda](https://github.com/Macro-swift/MacroLambda) has the bits to
directly deploy Macro applications on AWS Lambda.

## Streams

Checkout [Noze.io for people who don't know Node](http://noze.io/noze4nonnode/),
most things apply to Macro as well.

## What does it look like?

The Macro [Examples](https://github.com/Macro-swift/Examples) package 
contains a few examples which all can run straight from the source as
swift-sh scripts.

The most basic HTTP server:
```swift
#!/usr/bin/swift sh
import Macro // @Macro-swift ~> 0.8.0

http
  .createServer { req, res in
    res.writeHead(200, [ "Content-Type": "text/html" ])
    res.write("<h1>Hello Client: \(req.url)</h1>")
    res.end()
  }
  .listen(1337)
```

Macro also provides additional Node-like modules, such as:
- `fs`
- `path`
- `jsonfile`
- `JSON`
- `basicAuth`
- `querystring`


## Environment Variables

- `macro.core.numthreads`
- `macro.core.iothreads`
- `macro.core.retain.debug`
- `macro.concat.maxsize`
- `macro.streams.debug.rc`

### Links

- [µExpress](http://www.alwaysrightinstitute.com/microexpress-nio2/)
- [Noze.io](http://noze.io)
- [SwiftNIO](https://github.com/apple/swift-nio)
- JavaScript Originals
  - [Connect](https://github.com/senchalabs/connect)
  - [Express.js](http://expressjs.com/en/starter/hello-world.html)
- Swift Apache
  - [mod_swift](http://mod-swift.org)
  - [ApacheExpress](http://apacheexpress.io)

### Who

**Macro** is brought to you by
the
[Always Right Institute](http://www.alwaysrightinstitute.com)
and
[ZeeZide](http://zeezide.de).
We like 
[feedback](https://twitter.com/ar_institute), 
GitHub stars, 
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.

There is a `#microexpress` channel on the 
[Noze.io Slack](http://slack.noze.io/). Feel free to join!
