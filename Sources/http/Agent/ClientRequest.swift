//
//  ClientRequest.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import func   MacroCore.nextTick
import struct Foundation.TimeInterval
import struct Foundation.URL
import struct Foundation.URLComponents
import struct MacroCore.Buffer
import class  MacroCore.ErrorEmitter
import class  MacroCore.ReadableByteStream
import enum   MacroCore.EventListenerSet

public class ClientRequest: OutgoingMessage {

  @usableFromInline
  var responseListeners = EventListenerSet<IncomingMessage>()

  @inlinable
  @discardableResult
  public func onceResponse(execute: @escaping ( IncomingMessage ) -> Void)
              -> Self
  {
    responseListeners.once(execute)
    return self
  }
  @inlinable
  @discardableResult
  public func onResponse(execute: @escaping ( IncomingMessage ) -> Void)
              -> Self {
    onceResponse(execute: execute)
    return self
  }
}

public extension ClientRequest { // convenience
  
  @inlinable
  @discardableResult
  func onceResponse(execute: @escaping () -> Void) -> Self {
    return onceResponse { client in execute() }
  }
  @inlinable
  @discardableResult
  func onResponse(execute: @escaping () -> Void) -> Self {
    return onResponse { client in execute() }
  }

}

public extension HTTPModule {
  
  @discardableResult
  @inlinable
  static func get(options: ClientRequestOptions,
                  onResponse execute: (( IncomingMessage ) -> Void)? = nil)
              -> ClientRequest
  {
    var patched = options
    patched.method = "GET"
    let req = request(patched, onResponse: execute)
    req.end()
    return req
  }

  @discardableResult
  @inlinable
  static func get(_ url: URL, options: ClientRequestOptions = .init(),
                  onResponse execute: (( IncomingMessage ) -> Void)? = nil)
              -> ClientRequest
  {
    var patched = options
    patched.method = "GET"
    patched.url    = url
    let req = request(patched, onResponse: execute)
    req.end()
    return req
  }
  
  @discardableResult
  static func get(_ url: String, options: ClientRequestOptions = .init(),
                  onResponse execute: (( IncomingMessage ) -> Void)? = nil)
              -> ClientRequest
  {
    guard let url = URL(string: url) else {
      struct CouldNotParseURLError: Swift.Error {}
      let req = ClientRequest(unsafeChannel: nil,
                              log: options.resolvedAgent.options.logger)
      nextTick {
        req.emit(error: CouldNotParseURLError())
      }
      return req
    }
    var patched = options
    patched.method = "GET"
    patched.url    = url
    let req = request(patched, onResponse: execute)
    req.end()
    return req
  }
}

public extension HTTPModule {
  
  struct ClientRequestOptions {
    
    public enum AgentType {
      case `default`
      case global
      case custom(Agent)
    }
    
    public var agent   : AgentType
    
    /// Basic authentication String
    public var auth    : String?
    
    /// The HTTP headers to emit
    public var headers = [ String : String ]()
    
    /// The protocol to use. Note that this includes the trailing colon ...
    public var `protocol` = "http:"
    public var host       : String = "localhost"
    public var port       : Int?
    public var method     = "GET"
    public var path       = "/"
    public var setHost    = true
    
    /// The timeout in milliseconds.
    public var timeout    : Int? = nil
    
    public var hostname : String { set { host = newValue}  get { return host } }
    
    public var timeoutInterval : TimeInterval? {
      set { timeout = newValue.flatMap { Int($0 * 1000) } }
      get { return timeout.flatMap { TimeInterval($0) } }
    }

    @inlinable
    public init(agent: AgentType = .global)
    {
      self.agent = agent
    }
    
  }
  
  static func request(_ options: ClientRequestOptions,
                      onResponse execute: (( IncomingMessage ) -> Void)? = nil)
              -> ClientRequest
  {
    return options.resolvedAgent.request(options, onResponse: execute)
  }

  @inlinable
  static func request(_ url: URL, options: ClientRequestOptions = .init(),
                      onResponse execute: (( IncomingMessage ) -> Void)? = nil)
              -> ClientRequest
  {
    var patched = options
    patched.url = url
    return request(patched, onResponse: execute)
  }
}

extension HTTPModule.ClientRequestOptions {
  
  public var url : URL {
    set {
      if let v = newValue.scheme { self.`protocol` = v + ":" }
      if let v = newValue.host   { host = v }
      if let v = newValue.port   { port = v }
      path = newValue.path
      
      if let user = newValue.user {
        auth = user + ":\(newValue.password ?? "")"
      }
    }
    get {
      var s = self.`protocol` + "//" + host
      if let port = port { s += ":\(port)" }
      s += path
      guard let url = URL(string: s) else {
        fatalError("could not parse URL: \(s)")
      }
      return url
    }
  }
  
  internal var resolvedAgent : Agent {
    switch agent {
      case .`default`               : return URLSessionAgent()
      case .global                  : return HTTPModule.globalAgent
      case .custom(let customAgent) : return customAgent
    }
  }
}
