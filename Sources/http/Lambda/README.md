# Macro http.lambda

The files within simulate `http.createServer` but for AWS Lambda functions
addressed using the
AWS [API Gateway](https://aws.amazon.com/api-gateway/) V2.

Tutorial:
[Create your first HTTP endpoint with Swift on AWS Lambda](https://fabianfett.de/swift-on-aws-lambda-creating-your-first-http-endpoint))

Requests are regular `IncomingMessage` objects, responses are regular
`ServerResponse` objects.

Requests carry the additional `lambdaGatewayRequest` property to provide
access to the full Lambda JSON structure.

## Example

```swift
let server = lambda.createServer { req, res in
  req.log.info("request arrived in Macro land: \(req.url)")
  res.send("Hello You!")
}
server.run()
```

Note that the `run` function never returns.

## Package Setup

To keep Macro small, the Macro package does NOT actually import the Swift Lambda
runtime!
To make use of the package, import AWSLambdaRuntime and AWSLambdaEvents
alongside Macro and rebuild.

Example Package.swift:
```swift
// swift-tools-version:5.2
import PackageDescription

let package = Package(
  name         : "BlocksFun",
  platforms    : [ .macOS(.v10_13) ],
  dependencies : [
    .package(url: "https://github.com/swift-server/swift-aws-lambda-runtime.git",
             .upToNextMajor(from:"0.2.0")),
    .package(url: "https://github.com/Macro-swift/Macro.git",
             from: "0.6.0")
  ],
  targets: [
    .target(name: "BlocksFun",
            dependencies: [
              .product(name: "AWSLambdaRuntime",
                       package: "swift-aws-lambda-runtime"),
              .product(name: "AWSLambdaEvents",
                       package: "swift-aws-lambda-runtime"),
              "Macro"
            ])
  ]
)
```
