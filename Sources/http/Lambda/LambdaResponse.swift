//
//  LambdaResponse.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if canImport(AWSLambdaEvents)

import enum AWSLambdaEvents.APIGateway

extension ServerResponse {
  
  var asLambdaGatewayResponse: APIGateway.V2.Response {
    assert(writableEnded, "sending ServerResponse which didn't end?!")
    
    let ( singleHeaders, multiHeaders, cookies ) = headers.asLambda()
    
    let body : String? = {
      guard let writtenContent = writableBuffer, !writtenContent.isEmpty else {
        return nil
      }
      
      // TBD: We could make this more tolerant and use a String if the content
      //      is textual and can be converted to UTF-8? Would make it faster as
      //      well.
      do {
        return try writtenContent.toString("base64")
      }
      catch { // FIXME: make throwing
        log.error("could not convert body to base64: \(error)")
        return nil
      }
    }()
    
    return .init(statusCode        : status.asLambda,
                 headers           : singleHeaders,
                 multiValueHeaders : multiHeaders,
                 body              : body,
                 isBase64Encoded   : body != nil ? true : false,
                 cookies           : cookies)
  }
}

#endif // canImport(AWSLambdaEvents)
