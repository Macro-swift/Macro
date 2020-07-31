//
//  lambda.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if canImport(AWSLambdaRuntime)

public enum lambda {}

#if canImport(AWSLambdaEvents)

import let xsys.setenv

public extension lambda {
  
  /**
   * An `http.createServer` lookalike, but for AWS Lambda functions addressed
   * using the AWS API Gateway V2.
   *
   * Requests are regular `IncomingMessage` objects, responses are regular
   * `ServerResponse` objects.
   *
   * Requests carry the additional `lambdaGatewayRequest` property to provide
   * access to the full Lambda JSON structure.
   *
   * Example:
   *
   *     let server = createServer { req, res in
   *       req.log.info("request arrived in Macro land: \(req.url)")
   *       res.writeHead(200, [ "Content-Type": "text/html" ])
   *       res.end("<h1>Hello World</h1>")
   *     }
   *     server.run()
   *
   * Note that the `run` function never returns.
   */
  @inlinable
  @discardableResult
  static func createServer(handler: ((IncomingMessage, ServerResponse) -> Void)?
                           = nil)
              -> Server
  {
    // This is used the first time MacroCore.shared eventloop is accessed,
    // it shouldn't ever, but if it is, we just fork one thread :-)
    let magicKey = "macro.core.numthreads"
    setenv(magicKey, "1", 0 /* do not overwrite */)
    
    let server = Server()
    if let handler = handler { _ = server.onRequest(execute: handler) }
    return server
  }
}

#endif // canImport(AWSLambdaEvents)
#endif // canImport(AWSLambdaRuntime)
