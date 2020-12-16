//
//  URLSessionAgent.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import struct Logging.Logger
import struct Foundation.URL
import enum   NIOHTTP1.HTTPMethod

#if canImport(FoundationNetworking)
  import class  FoundationNetworking.URLSession
  import struct FoundationNetworking.URLRequest
#else
  import class  Foundation.URLSession
  import struct Foundation.URLRequest
#endif

/**
 * Some Node HTTP Agent API built on top of URLSession.
 */
public final class URLSessionAgent {
  
  public struct Options {
    // TODO: expose more URLSession options
    
    public var session : URLSession
    public var logger  : Logger
    
    public init(session: URLSession = .shared,
                logger: Logger = .init(label: "μ.http"))
    {
      self.session = session
      self.logger  = logger
    }
  }
  
  public var options : Options
  
  public init(options: Options = .init()) {
    self.options = options
  }

  
  // MARK: - Initiate Request
  
  @usableFromInline
  func request(_ options: HTTPModule.ClientRequestOptions,
               onResponse execute: (( IncomingMessage ) -> Void)? = nil)
       -> ClientRequest
  {
    // This one is a little weird, because URLSession seems to lack a streaming
    // HTTP body.
    // Or, well, it does have URLStreamTask. TODO :-) (rather do AHC)
    
    let loop       = MacroCore.shared.fallbackEventLoop()
    let urlRequest = URLRequest(options: options)
    let clientRequest =
      URLSessionClientRequest(agent: self, request: urlRequest, eventLoop: loop)
    if let execute = execute {
      clientRequest.onceResponse(execute: execute)
    }
    
    clientRequest.isWaitingForEnd = true
    if !clientRequest.isWaitingForEnd {
      clientRequest.startRequest()
    }
    
    return clientRequest
  }
}
