//
//  File.swift
//  
//
//  Created by Helge Heß on 11.12.20.
//

import Foundation

import struct Foundation.URL

#if canImport(FoundationNetworking)
  import struct FoundationNetworking.URLRequest
#else
  import struct Foundation.URLRequest
#endif

public extension URLRequest {
  
  init(options: HTTPModule.ClientRequestOptions) {
    if let timeInterval = options.timeoutInterval {
      self.init(url: options.url, cachePolicy: .useProtocolCachePolicy,
                timeoutInterval: timeInterval)
    }
    else {
      self.init(url: options.url)
    }
    
    httpMethod = options.method
    
    for ( name, value ) in options.headers {
      addValue(value, forHTTPHeaderField: name)
    }
    
    if options.setHost && value(forHTTPHeaderField: "Host") == nil {
      addValue(options.host, forHTTPHeaderField: "Host")
    }
    
    if let auth = options.auth {
      let b64 = Data(auth.utf8).base64EncodedString()
      setValue("Basic " + b64, forHTTPHeaderField: "Authorization")
    }
  }
}
