//
//  LambdaNIOConversions.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if canImport(AWSLambdaEvents)
import struct NIOHTTP1.HTTPRequestHead
import struct NIOHTTP1.HTTPVersion
import enum   NIOHTTP1.HTTPMethod
import struct NIOHTTP1.HTTPHeaders
import enum   NIOHTTP1.HTTPResponseStatus

import struct AWSLambdaEvents.HTTPMethod
import struct AWSLambdaEvents.HTTPHeaders
import struct AWSLambdaEvents.HTTPMultiValueHeaders
import struct AWSLambdaEvents.HTTPResponseStatus

internal extension AWSLambdaEvents.HTTPMethod {
  
  @inlinable
  var asNIO: NIOHTTP1.HTTPMethod {
    switch self {
      case .GET     : return .GET
      case .POST    : return .POST
      case .PUT     : return .PUT
      case .PATCH   : return .PATCH
      case .DELETE  : return .DELETE
      case .OPTIONS : return .OPTIONS
      case .HEAD    : return .HEAD
      default       : return .RAW(value: rawValue)
    }
  }
}

internal extension AWSLambdaEvents.HTTPHeaders {
  
  @inlinable
  var asNIO: NIOHTTP1.HTTPHeaders {
    get {
      var headers = NIOHTTP1.HTTPHeaders()
      for ( name, value ) in self {
        headers.add(name: name, value: value)
      }
      return headers
    }
  }
}

internal extension AWSLambdaEvents.HTTPMultiValueHeaders {
  
  @inlinable
  var asNIO: NIOHTTP1.HTTPHeaders {
    set {
      for ( name, value ) in newValue {
        self[name, default: []].append(value)
      }
    }
    get {
      var headers = NIOHTTP1.HTTPHeaders()
      for ( name, values ) in self {
        for value in values {
          headers.add(name: name, value: value)
        }
      }
      return headers
    }
  }
}

internal extension NIOHTTP1.HTTPHeaders {
  
  @inlinable
  func asLambda() -> ( single  : AWSLambdaEvents.HTTPHeaders?,
                       multi   : AWSLambdaEvents.HTTPMultiValueHeaders?,
                       cookies : [ String ]? )
  {
    guard !isEmpty else { return ( nil, nil, nil ) }
    
    // Those do no proper CI, lets hope they are consistent
    var single  = AWSLambdaEvents.HTTPHeaders()
    var multi   = AWSLambdaEvents.HTTPMultiValueHeaders()
    var cookies = [ String ]()
    
    // Schnüff, we don't get NIO's `compareCaseInsensitiveASCIIBytes`
    for ( name, value ) in self {
      // This is all not good. But neither is the JSON gateway :-)
      if name.caseInsensitiveCompare("Set-Cookie") == .orderedSame ||
         name.caseInsensitiveCompare("Cookie")     == .orderedSame
      {
        cookies.append(value)
      }
      else {
        if let other = single.removeValue(forKey: name) {
          assert(multi[name] == nil)
          multi[name, default:[]].append(other)
        }
        multi[name, default:[]].append(value)
      }
    }

    return ( single  : single .isEmpty ? nil : single,
             multi   : multi  .isEmpty ? nil : multi,
             cookies : cookies.isEmpty ? nil : cookies )
  }
}

internal extension NIOHTTP1.HTTPResponseStatus {

  @inlinable
  var asLambda : AWSLambdaEvents.HTTPResponseStatus { // why, o why
    return .init(code: UInt(code), reasonPhrase: reasonPhrase)
  }
}

internal extension AWSLambdaEvents.HTTPResponseStatus {
  
  @inlinable
  var asNIO : NIOHTTP1.HTTPResponseStatus { // why, o why
    return .init(statusCode: Int(code),
                 reasonPhrase: reasonPhrase ?? "HTTP Status \(code)")
  }
}
#endif // canImport(AWSLambdaEvents)
