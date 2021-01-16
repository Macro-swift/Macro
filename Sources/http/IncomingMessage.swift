//
//  IncomingMessage.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   Logging.Logger
import protocol NIO.Channel
import struct   NIOHTTP1.HTTPRequestHead
import struct   NIOHTTP1.HTTPResponseHead
import enum     NIOHTTP1.HTTPMethod
import struct   NIOHTTP1.HTTPVersion
import struct   NIOHTTP1.HTTPHeaders
import enum     NIOHTTP1.HTTPResponseStatus
import struct   MacroCore.Buffer
import class    MacroCore.ErrorEmitter
import class    MacroCore.ReadableByteStream
import func     MacroCore.nextTick
import struct   MacroCore.EnvironmentValues
import protocol MacroCore.EnvironmentValuesHolder

/**
 * Represents an incoming HTTP message.
 * 
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
 * Hierarchy:
 *
 * - ErrorEmitter
 *   - ReadableStreamBase
 *     - ReadableByteStream
 *       * IncomingMessage
 */
open class IncomingMessage: ReadableByteStream, CustomStringConvertible {
  
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
  public var log  : Logger
  
  public private(set) var socket : NIO.Channel?

  /**
   * Use `EnvironmentKey`s to store extra information alongside requests.
   * This is similar to using a Node/Express `locals` dictionary (or attaching
   * directly properties to a request), but typesafe.
   *
   * For example a database connection associated with the request,
   * or some extra data a custom bodyParser parsed.
   *
   * Example:
   *
   *     enum LoginUserEnvironmentKey: EnvironmentKey {
   *       static let defaultValue = ""
   *     }
   *
   * In addition to the key definition, one usually declares an accessor to the
   * respective environment holder, for example the `IncomingMessage`:
   *
   *     extension IncomingMessage {
   *
   *       var loginUser : String {
   *         set { self[LoginUserEnvironmentKey.self] = newValue }
   *         get { self[LoginUserEnvironmentKey.self] }
   *       }
   *     }
   *
   */
  public var environment = MacroCore.EnvironmentValues.empty
  
  @available(*, deprecated, message: "Please use the regular `log` w/ `.error`")
  @inlinable
  override open var errorLog : Logger { return log } // this was a mistake

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
  
  
  // MARK: - Initialization

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
  
  
  // MARK: - Description
  
  open var description: String {
    let id : String = {
      let oids = ObjectIdentifier(self).debugDescription
      // ObjectIdentifier(0x000000010388a610)
      let dropPrefix = "ObjectIdentifier(0x000000"
      guard oids.hasPrefix(dropPrefix) else { return oids }
      return "0x" + oids.dropFirst(dropPrefix.count).dropLast()
    }()
    
    var ms = "<IncomingMessage[\(id)]:"
    defer { ms += ">" }
    
    if      socket         == nil { ms += " no-socket"       }
    else if flowingToggler == nil { ms += " no-flow-toggler" }
    
    if let buffered = readableBuffer, !buffered.isEmpty {
      ms += " buffered=\(buffered.count)"
    }
    
    switch head {
      case .request  : ms += " \(method) \(url)"
      case .response : ms += " \(statusCode)"
    }

    if readableEnded { ms += " ended" }
    
    if !readableListeners.isEmpty { ms += " has-readable-listeners" }
    if !dataListeners    .isEmpty { ms += " has-data-listeners"     }

    if !environment.isEmpty {
      ms += "\n"
      for ( key, value ) in environment.loggingDictionary {
        ms += "  \(key)=\(value)\n"
      }
    }

    return ms
  }
}

extension IncomingMessage: EnvironmentValuesHolder {}
extension IncomingMessage: HTTPHeadersHolder       {}

public extension IncomingMessage {
  
  /**
   * Convenience method to quickly create an IncomingMessage for a synthesized
   * request.
   *
   * - Parameters:
   *   - method  : The HTTP method, defaults to `.GET`
   *   - url     : The path (or URL in case of proxies), e.g. `/hello`
   *   - version : The HTTP version to use, defaults to 1.1
   *   - headers : An optional set of headers to use
   *   - body    : The request body, if set the data is pushed and the finished
   *               (i.e. the stream is marked `readableEnded`).
   */
  @inlinable
  convenience init(method  : HTTPMethod  = .GET,
                   url     : String,
                   version : HTTPVersion = .init(major: 1, minor: 1),
                   headers : HTTPHeaders = [:],
                   body    : Buffer?     = nil)
  {
    let head = HTTPRequestHead(version: version, method: method, uri: url,
                               headers: headers)
    self.init(head)
    
    if let body = body {
      push(body)
      push(nil)
    }
  }

  
  /**
   * Convenience method to quickly create an IncomingMessage for a synthesized
   * response.
   *
   * - Parameters:
   *   - status  : The HTTP response status
   *   - version : The HTTP version to use, defaults to 1.1
   *   - headers : An optional set of headers to use
   *   - body    : The request body, if set the data is pushed and the finished
   *               (i.e. the stream is marked `readableEnded`).
   */
  @inlinable
  convenience init(status  : HTTPResponseStatus,
                   version : HTTPVersion = .init(major: 1, minor: 1),
                   headers : HTTPHeaders = [:],
                   body    : Buffer?     = nil)
  {
    let head = HTTPResponseHead(version: version, status: status,
                                headers: headers)
    self.init(head)
    
    if let body = body {
      push(body)
      push(nil)
    }
  }
}
