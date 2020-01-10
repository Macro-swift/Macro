//
//  IncomingMessage.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   Logging.Logger
import protocol NIO.Channel
import struct   NIOHTTP1.HTTPRequestHead
import struct   NIOHTTP1.HTTPResponseHead
import struct   NIOHTTP1.HTTPVersion
import struct   NIOHTTP1.HTTPHeaders
import enum     NIOHTTP1.HTTPResponseStatus
import class    MacroCore.ErrorEmitter
import class    MacroCore.ReadableByteStream
import enum     MacroCore.EventListenerSet
import func     MacroCore.nextTick

/**
 * This can be both, a Request or a Response - it is a Response when it got
 * created by a client and it is a Request if it is coming from the Server.
 *
 * You don't usually create this directly, but get it as an argument in a
 * middleware function, e.g. it is the `req` argument in this case:
 *
 *     http.createServer { req, res in
 *       req.log.info("got message:", req.method)
 *     }
 *
 */
open class IncomingMessage: ReadableByteStream {
  
  public enum IncomingType {
    case request (HTTPRequestHead)
    case response(HTTPResponseHead)
    
    @inlinable
    public var version : HTTPVersion {
      set {
        switch self {
          case .request (var request):
            request.version = newValue
            self = .request(request)
          case .response(var response):
            response.version = newValue
            self = .response(response)
        }
      }
      get {
        switch self {
          case .request (let request)  : return request .version
          case .response(let response) : return response.version
        }
      }
    }
    @inlinable
    public var headers : HTTPHeaders {
      set {
        switch self {
          case .request (var request):
            request .headers = newValue
            self = .request(request)
          case .response(var response):
            response.headers = newValue
          self = .response(response)
        }
      }
      get {
        switch self {
          case .request (let request)  : return request .headers
          case .response(let response) : return response.headers
        }
      }
    }
  }
  
  public var head : IncomingType
  public let log  : Logger
  
  public private(set) var socket : NIO.Channel?

  /// Store extra information alongside the request. Try to use unique keys,
  /// e.g. via reverse-DNS to avoid middleware conflicts.
  public var extra = [ String : Any ]()

  @inlinable
  override open var errorLog : Logger { return log }

  public internal(set) var complete : Bool = false {
    didSet {
      guard complete != oldValue else { return }
      if complete { didComplete() }
    }
  }
  
  private func didComplete() {
    readableEnded  = true // TBD: just use `complete` for this?
    flowingToggler = nil
    
    endListeners.emit()
    
    dataListeners    .removeAll()
    readableListeners.removeAll()
    endListeners     .removeAll()
    errorListeners   .removeAll()
    
    socket = nil
  }
  
  internal var flowingToggler : (( Bool ) -> Void)?

  public init(_ head : HTTPRequestHead,
              socket : NIO.Channel? = nil,
              log    : Logger = .init(label: "μ.http"))
  {
    self.log    = log
    self.head   = .request(head)
    self.socket = socket
  }
  public init(_ head : HTTPResponseHead,
              socket : NIO.Channel? = nil,
              log    : Logger = .init(label: "μ.http"))
  {
    self.log    = log
    self.head   = .response(head)
    self.socket = socket
  }
  
  
  // MARK: - HTTP Responses

  @inlinable
  var status : HTTPResponseStatus {
    guard case .response(let request) = head else { return .notImplemented }
    return request.status
  }
  
  
  // MARK: - Readable Stream
  
  override open var readableFlowing : Bool {
    didSet {
      // TBD: I think `flowing` refers to `data` vs `readable` events, not
      //      whether the connection is paused. Read up on that :-)
      guard oldValue != readableFlowing else { return }
      flowingToggler?(readableFlowing)
    }
  }

  // MARK: - Node like API

  @inlinable
  public var httpVersion : String { return head.version.description }

  // TBD
  @inlinable
  public var headers : HTTPHeaders { return head.headers }

  // MARK: - HTTP Requests
  
  @inlinable
  public var method : String {
    set {
      switch head {
        case .request(var request):
          request.method = .init(rawValue: newValue)
          self.head = .request(request)
        case .response:
          log.error("attempt to set method of response")
          assertionFailure("attempt to set method of response?")
          return
      }
    }
    get {
      guard case .request(let request) = head else { return "" }
      return request.method.rawValue
    }
  }
  
  @inlinable
  public var url : String {
    guard case .request(let request) = head else { return "" }
    return request.uri
  }
  
  // MARK: - HTTP Responses
 
  @inlinable
  public var statusCode : Int {
    guard case .response(let request) = head else { return 0 }
    return Int(request.status.code)
  }
  
  @inlinable
  public var statusMessage : String? {
    guard case .response(let request) = head else { return nil }
    return request.status.reasonPhrase
  }
}

extension IncomingMessage: HTTPHeadersHolder {}

extension IncomingMessage: CustomStringConvertible {

  public var description: String {
    var ms = "<IncomingMessage[\(ObjectIdentifier(self))]:"
    defer { ms += ">" }
    
    if      socket         == nil { ms += " no-socket"       }
    else if flowingToggler == nil { ms += " no-flow-toggler" }
    
    switch head {
      case .request  : ms += " \(method) \(url)"
      case .response : ms += " \(statusCode)"
    }

    if readableEnded { ms += " ended" }

    for ( key, value ) in extra { ms += " \(key)=\(value)" }
    
    return ms
  }
}
