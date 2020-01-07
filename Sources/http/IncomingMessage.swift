//
//  IncomingMessage.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   Logging.Logger
import struct   NIO.ByteBuffer
import struct   NIO.ByteBufferAllocator
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
      switch self {
        case .request (let request): return request.version
        case .response(let request): return request.version
      }
    }
    @inlinable
    public var headers : HTTPHeaders {
      switch self {
        case .request (let request): return request.headers
        case .response(let request): return request.headers
      }
    }
  }
  
  public let head : IncomingType
  public let log  : Logger

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
  }
  
  internal var flowingToggler : (( Bool ) -> Void)?

  @inlinable
  public init(_ head: HTTPRequestHead,
              log: Logger = .init(label: "μ.http"))
  {
    self.log  = log
    self.head = .request(head)
  }
  @inlinable
  public init(_ head: HTTPResponseHead,
              log: Logger = .init(label: "μ.http"))
  {
    self.log  = log
    self.head = .response(head)
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
    guard case .request(let request) = head else { return "" }
    return request.method.rawValue
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
