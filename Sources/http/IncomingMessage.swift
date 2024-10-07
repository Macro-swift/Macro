//
//  IncomingMessage.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
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
 * This can be both, a request or a response - it is a response when it got
 * created by a client and it is a request if it is coming from the server.
 *
 * This isn't usually created directly, but passed inas an argument in a
 * middleware function, e.g. it is the `req` argument in this case:
 * ```
 * http.createServer { req, res in
 *   req.log.info("got message:", req.method)
 * }
 * ```
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
    
    /// Set or get the `HTTPVersion` of the message.
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

    /// Set or get the `HTTPHeaders` of the message.
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
  
  /// The HTTP header for the ``IncomingMessage``, can be either a request or
  /// a response.
  public var head : IncomingType
  
  /// The `Logger` associated with the request, use it to log request related
  /// messages.
  public var log  : Logger
  
  /// The SwiftNIO `Channel` backing the message.
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

  /// Whether the message was read completedly.
  public internal(set) var complete : Bool = false {
    didSet {
      guard complete != oldValue else { return }
      if complete { didComplete() }
    }
  }
  
  public var destroyed : Bool = false
  
  @discardableResult
  open func destroy(_ error: Swift.Error? = nil) -> Self {
    guard !destroyed else { return self }
    destroyed = true
    if let error = error { emit(error: error) }
    _ = socket?.close(mode: .input)
    didComplete()
    return self
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

  /**
   * Create a new ``IncomingMessage`` request object from a `HTTPRequestHead`.
   *
   * - Parmeters:
   *   - head:   The SwiftNIO `HTTPRequestHead` structure.
   *   - socket: The associated SwiftNIO `Channel`, if there is one, defaults to
   *             `nil`.
   *   - log:    The `Logger` associated w/ the message (defaults to "μ.http").
   */
  public init(_ head : HTTPRequestHead,
              socket : NIO.Channel? = nil,
              log    : Logger = .init(label: "μ.http"))
  {
    self.log    = log
    self.head   = .request(head)
    self.socket = socket
  }

  /**
   * Create a new ``IncomingMessage`` response object from a `HTTPResponseHead`.
   *
   * - Parmeters:
   *   - head:   The SwiftNIO `HTTPRequestHead` structure.
   *   - socket: The associated SwiftNIO `Channel`, if there is one, defaults to
   *             `nil`.
   *   - log:    The `Logger` associated w/ the message (defaults to "μ.http").
   */
  public init(_ head : HTTPResponseHead,
              socket : NIO.Channel? = nil,
              log    : Logger = .init(label: "μ.http"))
  {
    self.log    = log
    self.head   = .response(head)
    self.socket = socket
  }
  
  
  // MARK: - HTTP Responses

  /// Returns the `HTTPResponseStatus` of the message (e.g. `.ok`).
  /// Returns `.notImplemented` for requests.
  @inlinable
  public var status : HTTPResponseStatus {
    switch head {
      case .response(let response) : return response.status
      case .request(_)             : return .notImplemented
    }
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

  /// Returns the textual HTTP protocol version associated with the message.
  /// A structured version can be retrieved using `head.version`.
  @inlinable
  public var httpVersion : String { return head.version.description }

  /// Returns the HTTP headers associated with the message.
  @inlinable
  public var headers : HTTPHeaders { return head.headers }

  
  // MARK: - HTTP Requests
  
  /// The textual HTTP method associated with the HTTP request.
  /// If it is a response, setting this has no effect and retrieving it returns
  /// an empty string.
  /// The structured `HTTPMethod` can be retrieved using the head.
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
      switch head {
        case .request(let request) : return request.method.rawValue
        case .response(_)          : return ""
      }
    }
  }
  
  /// The URI associated with the request as a plain string.
  /// Returns an empty string for responses.
  @inlinable
  public var url : String {
    switch head {
      case .request(let request) : return request.uri
      case .response(_)          : return ""
    }
  }
  
  
  // MARK: - HTTP Responses
 
  /// The numeric HTTP status code associated with a response (e.g. 200).
  /// Returns 0 for HTTP requests.
  @inlinable
  public var statusCode : Int {
    switch head {
      case .request(_)             : return 0
      case .response(let response) : return Int(response.status.code)
    }
  }
  
  /// The textual HTTP status code associated with a response (e.g. "OK").
  /// Returns nil for HTTP requests.
  @inlinable
  public var statusMessage : String? {
    switch head {
      case .request(_)             : return nil
      case .response(let response) : return response.status.reasonPhrase
    }
  }
  
  
  // MARK: - Description
  
  open var description: String {
    let id = "0x" + String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    var ms = "<IncomingMessage[\(id)]:"
    defer { ms += ">" }
    
    if socket == nil {
      if !readableEnded { ms += " no-socket" }
    }
    else if flowingToggler == nil {
      ms += " no-flow-toggler"
    }
    
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
