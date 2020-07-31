//
//  LambdaRequest.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if canImport(AWSLambdaEvents)

import struct Logging.Logger
import struct NIOHTTP1.HTTPRequestHead
import enum   AWSLambdaEvents.APIGateway
import struct MacroCore.Buffer
import class  http.IncomingMessage

public extension IncomingMessage {
  
  convenience init(lambdaRequest : APIGateway.V2.Request,
                   log           : Logger = .init(label: "μ.http"))
  {
    // version doesn't matter, we don't really do HTTP
    var head = HTTPRequestHead(
      version : .init(major: 1, minor: 1),
      method  : lambdaRequest.context.http.method.asNIO,
      uri     : lambdaRequest.context.http.path
    )
    head.headers = lambdaRequest.headers.asNIO
    
    if let cookies = lambdaRequest.cookies, !cookies.isEmpty {
      // So our "connect" module expects them in the headers, so we'd need
      // to serialize them again ...
      // The `IncomingMessage` also has a `cookies` getter, but I think that
      // isn't cached.
      for cookie in cookies { // that is weird too, is it right?
        head.headers.add(name: "Cookie", value: cookie)
      }
    }
    
    // TBD: there is also "pathParameters", what is that, URL fragments (#)?
    if let pathParams = lambdaRequest.pathParameters, !pathParams.isEmpty {
      log.warning("ignoring lambda path parameters: \(pathParams)")
    }
    
    if let qsParameters = lambdaRequest.queryStringParameters,
       !qsParameters.isEmpty
    {
      // TBD: is that included in the path?
      var isFirst = false
      if !head.uri.contains("?") { head.uri.append("?"); isFirst = true }
      for ( key, value ) in qsParameters {
        if isFirst { isFirst = false }
        else { head.uri += "&" }
        
        head.uri +=
          key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          ?? key
        head.uri += "="
        head.uri +=
          value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          ?? value
      }
    }

    self.init(head, socket: nil, log: log)
    
    // and keep the whole thing
    lambdaGatewayRequest = lambdaRequest
  }
  
  internal func sendLambdaBody(_ lambdaRequest: APIGateway.V2.Request) {
    defer { push(nil) }
    
    guard let body = lambdaRequest.body else { return }
    do {
      if lambdaRequest.isBase64Encoded {
        push(try Buffer.from(body, encoding: "base64"))
      }
      else {
        push(try Buffer.from(body))
      }
    }
    catch {
      emit(error: error)
    }
  }
}

fileprivate let lambdaRequestKey = "macro.lambda.request"

public extension IncomingMessage {
  
  var lambdaGatewayRequest: APIGateway.V2.Request? {
    set { extra[lambdaRequestKey] = newValue }
    get {
      guard let req = extra[lambdaRequestKey] else { return nil }
      assert(req is APIGateway.V2.Request)
      return req as? APIGateway.V2.Request
    }
  }
}
#endif // canImport(AWSLambdaEvents)
