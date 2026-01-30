//
//  WebSocket.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct    Foundation.URL
import struct    Foundation.Data
import class     Foundation.JSONEncoder
import class     Foundation.JSONDecoder
import class     Foundation.JSONSerialization
import struct    Logging.Logger
import class     MacroCore.ErrorEmitter
import enum      MacroCore.EventListenerSet
import typealias NIOHTTP1.NIOHTTPClientUpgradeConfiguration
import typealias NIOHTTP1.HTTPClientResponsePart
import typealias NIOHTTP1.HTTPClientRequestPart
import struct    NIOHTTP1.HTTPHeaders
import struct    NIOHTTP1.HTTPRequestHead
import struct    NIOHTTP1.HTTPResponseHead
import struct    NIOHTTP1.HTTPVersion

// during dev
import MacroCore
import NIO
import NIOWebSocket

/**
 * A WebSocket connection.
 *
 * This is used for both, client initiated sockets and server initiated ones.
 *
 * It also acts as a namespace for the `WebSocket.Server` class.
 *
 * Client Example:
 *
 *     import ws
 *
 *     let ws = WebSocket("ws://echo.websocket.org/")
 *     ws.onOpen { ws in
 *       console.log("Connection available ...")
 *       ws.send("Hello!")
 *     }
 *     ws.onMessage { message in
 *       console.log("Received:", message)
 *     }
 *
 * Server Example:
 *
 *     import ws
 *
 *     let wss = WebSocket.Server(port: 8080)
 *     wss.onConnection { ws in
 *       ws.onMessage { message in
 *         console.log("Received:", message)
 *       }
 *
 *       ws.send("Hello!")
 *     }
 *
 */
open class WebSocket: ErrorEmitter {

  // MARK: - Types

  /**
   * WebSocket connection ready state, matching the Node.js ws library.
   *
   * - `connecting`: The connection is not yet open.
   * - `open`: The connection is open and ready to communicate.
   * - `closing`: The connection is in the process of closing.
   * - `closed`: The connection is closed.
   */
  public enum ReadyState: Int, Sendable {
    case connecting = 0
    case open       = 1
    case closing    = 2
    case closed     = 3
  }

  public enum WebSocketError: Swift.Error {
    case connectionNotOpen
    case upgradeFailed       (status: Int?)
    case invalidURL          (String)
    case unsupportedURLScheme(URL)
    case missingPortInURL    (URL)
  }

  // MARK: - Properties

  open                var log        : Logger
  public private(set) var channel    : Channel?
  public private(set) var readyState : ReadyState = .connecting

  public var isConnected : Bool { return readyState == .open && channel != nil }

  private var didRetain = false

  /**
   * Initialize the WebSocket with a fully setup and configured NIO `Channel`.
   *
   * Used by the server.
   */
  @usableFromInline
  init(_ channel: Channel?, log: Logger? = nil) {
    self.channel    = channel
    self.log        = log ?? .init(label: "μ.ws")
    self.readyState = channel != nil ? .open : .connecting
    super.init()
    
    if channel != nil, !didRetain { didRetain = true; core.retain() }
  }
  deinit {
    if didRetain { core.release(); didRetain = false }
  }

  convenience
  public init(_ url: URL, log: Logger? = nil) {
    self.init(nil, log: log)
    
    guard let bootstrap = bootstrapForURL(url) else {
      nextTick {
        self.emit(error: WebSocketError.unsupportedURLScheme(url))
      }
      return
    }
    
    if !didRetain { didRetain = true; core.retain() }
    if let host = url.host {
      guard let port = url.port ?? defaultPortForScheme(url.scheme) else {
        nextTick {
          self.emit(error: WebSocketError.missingPortInURL(url))
        }
        return
      }
      
      bootstrap.connect(host: host, port: port)
        .whenComplete(self.handleConnectResult)
    }
    else {
      bootstrap.connect(unixDomainSocketPath: url.path)
        .whenComplete(self.handleConnectResult)
    }
  }
  
  convenience
  public init(_ url: String, log: Logger? = nil) {
    guard let parsedURL = URL(string: url) else {
      self.init(nil, log: log)
      
      nextTick {
        self.emit(error: WebSocketError.invalidURL(url))
      }
      return
    }
    
    self.init(parsedURL, log: log)
  }

  
  // MARK: - Event Handlers

  private var _closeListeners   = EventListenerSet<Void>()
  private var _messageListeners = EventListenerSet<( Any )>()
  private var _textListeners    = EventListenerSet<String>()
  private var _dataListeners    = EventListenerSet<Data>()
  private var _pongListeners    = EventListenerSet<Void>()
  private var _openListeners    = EventListenerSet<WebSocket>()

  @discardableResult
  public func onOpen(execute: @escaping ( WebSocket ) -> Void) -> Self {
    _openListeners.add(execute)
    return self
  }

  @discardableResult
  public func onPong(execute: @escaping () -> Void) -> Self {
    _pongListeners.add(execute)
    return self
  }
  
  @discardableResult
  public func onMessage(execute: @escaping ( Any ) -> Void) -> Self {
    _messageListeners.add(execute)
    return self
  }

  /**
   * Register a listener for text messages.
   *
   * Unlike the generic `onMessage`, this directly provides the raw text
   * string without JSON parsing.
   */
  @discardableResult
  public func onText(execute: @escaping ( String ) -> Void) -> Self {
    _textListeners.add(execute)
    return self
  }

  @discardableResult
  public func onMessage<T: Decodable>(execute: @escaping ( T ) -> Void) -> Self
  {
    // Note: self-cycle, but that is OK, will be broken on close!
    _dataListeners.add { [self] data in
      do {
        let message = try JSONDecoder().decode(T.self, from: data)
        execute(message)
      }
      catch {
        self.emit(error: error)
      }
    }
    return self
  }

  @discardableResult
  public func onClose(execute: @escaping () -> Void) -> Self {
    _closeListeners.add(execute)
    return self
  }

  func emitMessage(_ message: Any) {
    _messageListeners.emit(message)
  }
  func emitText(_ text: String) {
    _textListeners.emit(text)
  }
  func emitPong() {
    _pongListeners.emit()
  }
  func emitOpen() {
    readyState = .open
    _openListeners.emit(self)
  }

  /**
   * Close the WebSocket connection gracefully.
   *
   * Sends a close frame with the optional status code and reason, then closes
   * the underlying channel.
   *
   * - Parameters:
   *   - code: Optional close status code (default: 1000 for normal closure).
   *   - reason: Optional close reason string (max 123 bytes).
   */
  public func close(code: UInt16 = 1000, reason: String = "") {
    guard readyState == .open || readyState == .connecting else { return }
    readyState = .closing

    guard let channel = channel else {
      readyState = .closed
      _closeListeners.emit( () )
      cleanupListeners()
      return
    }

    // Build close frame with code and reason
    var data = channel.allocator.buffer(capacity: 2 + reason.utf8.count)
    data.writeInteger(code)
    if !reason.isEmpty {
      // Limit reason to 123 bytes per WebSocket spec
      data.writeBytes(reason.utf8.prefix(123))
    }

    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    channel.writeAndFlush(frame).whenComplete { [weak self] _ in
      self?.finishClose()
    }
  }

  /**
   * Immediately terminate the connection without sending a close frame.
   *
   * Use this for hard disconnects when you don't need a graceful shutdown.
   */
  public func terminate() {
    guard readyState != .closed else { return }
    readyState = .closed

    channel?.close(mode: .all, promise: nil)
    channel = nil

    _closeListeners.emit( () )
    cleanupListeners()

    if didRetain { didRetain = false; core.release() }
  }

  private func finishClose() {
    guard readyState != .closed else { return }
    readyState = .closed

    channel?.close(mode: .all, promise: nil)
    channel = nil

    _closeListeners.emit( () )
    cleanupListeners()

    if didRetain { didRetain = false; core.release() }
  }

  private func cleanupListeners() {
    _messageListeners.removeAll()
    _dataListeners   .removeAll()
    _closeListeners  .removeAll()
    _openListeners   .removeAll()
    _pongListeners   .removeAll()
  }

  /// Called by `WebSocketConnection` when remote closes the connection.
  func handleRemoteClose() {
    guard readyState != .closed else { return }
    readyState = .closed

    channel = nil

    _closeListeners.emit( () )
    cleanupListeners()

    if didRetain { didRetain = false; core.release() }
  }
  
  
  // MARK: - Sending Data

  /**
   * Send a ping frame to the remote peer.
   *
   * The remote should respond with a pong frame, which will trigger the
   * `onPong` listeners.
   *
   * - Parameter data: Optional payload data for the ping (max 125 bytes).
   */
  public func ping(_ data: Data? = nil) {
    guard let channel = channel, readyState == .open else {
      return emit(error: WebSocketError.connectionNotOpen)
    }

    var buffer: ByteBuffer
    if let data = data {
      buffer = channel.allocator.buffer(capacity: min(data.count, 125))
      buffer.writeBytes(data.prefix(125))
    }
    else {
      buffer = channel.allocator.buffer(capacity: 0)
    }

    let frame = WebSocketFrame(fin: true, opcode: .ping, data: buffer)
    channel.writeAndFlush(frame).whenFailure(self.emit(error:))
  }

  /**
   * Send a text message (raw string, not JSON encoded).
   *
   * - Parameter text: The text string to send.
   */
  public func send(text: String) {
    send(binary: Data(text.utf8), opcode: .text)
  }

  /**
   * Send binary data.
   *
   * - Parameter binary: The binary data to send.
   */
  public func send(binary data: Data,
                   opcode: WebSocketOpcode = .binary)
  {
    guard let channel = channel, readyState == .open else {
      return emit(error: WebSocketError.connectionNotOpen)
    }

    var buffer = channel.allocator.buffer(capacity: data.count)
    buffer.writeBytes(data)

    let frame = WebSocketFrame(fin: true, opcode: opcode, data: buffer)
    channel.writeAndFlush(frame).whenFailure(self.emit(error:))
  }

  /**
   * Send an Encodable value as JSON.
   */
  @inlinable
  public func send<T: Encodable>(_ message: T) {
    do {
      let data = try JSONEncoder().encode(message)
      send(binary: data, opcode: .text)
    }
    catch {
      emit(error: error)
    }
  }

  /**
   * Send a JSON-serializable object.
   */
  @inlinable
  public func send(_ message: Any) {
    do {
      #if os(Linux)
        let opts : JSONSerialization.WritingOptions = []
      #else
        let opts : JSONSerialization.WritingOptions = [ .fragmentsAllowed ]
      #endif
      let data = try JSONSerialization.data(withJSONObject: message,
                                            options: opts)
      send(binary: data, opcode: .text)
    }
    catch {
      emit(error: error)
    }
  }

  
  
  // MARK: - Receiving Data

  func processIncomingText(_ text: String, data: Data) {
    _textListeners.emit(text)
    _dataListeners.emit(data)
    
    if !_messageListeners.isEmpty {
      do {
        #if os(Linux)
          let opts : JSONSerialization.ReadingOptions = []
        #else
          let opts : JSONSerialization.ReadingOptions = [ .fragmentsAllowed ]
        #endif
        let json = try JSONSerialization.jsonObject(with: data, options: opts)
        _messageListeners.emit(json)
      }
      catch {
        emit(error: error)
      }
    }
  }

  func processIncomingBinary(_ data: Data) {
    _dataListeners.emit(data)
  }
  
  
  // MARK: - Client Setup
  
  private func handleConnectResult(_ result: Result<Channel, Error>) {
    switch result {
      case .failure(let error):
        nextTick {
          self.emit(error: error)
        }
        
      case .success(let channel):
        assert(self.channel == nil)
        self.channel = channel
    }
  }

  private static let webSocketHandlerName = "μ.ws.client.handler"
  private static let httpHandlerName      = "μ.ws.client.http"
  
  private final class HTTPHandler: ChannelInboundHandler,
                                   RemovableChannelHandler
  {
    public typealias InboundIn   = HTTPClientResponsePart
    public typealias OutboundOut = HTTPClientRequestPart

    var ws         : WebSocket?
    var path       : String
    var host       : String
    var requestKey : String

    init(path: String, host: String, requestKey: String, ws: WebSocket) {
      self.path       = path
      self.host       = host
      self.requestKey = requestKey
      self.ws         = ws
    }
    
    public func channelActive(context: ChannelHandlerContext) {
      let headers: HTTPHeaders = [
        "Host"                  : host,
        "Upgrade"               : "websocket",
        "Connection"            : "Upgrade",
        "Sec-WebSocket-Key"     : requestKey,
        "Sec-WebSocket-Version" : "13"
      ]
      let req = HTTPRequestHead(version : .init(major: 1, minor: 1),
                                method  : .GET, uri: path, headers: headers)
      context.write(self.wrapOutboundOut(.head(req)), promise: nil)
      context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      // Only invoked if upgrade failed
      let clientResponse = self.unwrapInboundIn(data)
      
      switch clientResponse {
        case .head(let res):
          ws?.emit(error: WebSocketError
                            .upgradeFailed(status: Int(res.status.code)))
          ws = nil
        case .body : break
        case .end  :
          ws?.emit(error: WebSocketError.upgradeFailed(status: nil))
          ws = nil
          context.close(promise: nil)
      }
    }
    
    public func handlerRemoved(context: ChannelHandlerContext) {
      self.ws = nil
    }
    
    public func errorCaught(context: ChannelHandlerContext, error: Error) {
      ws?.emit(error: error)
      context.close(promise: nil)
    }
  }
  
  // API: TBD
  typealias WebSocketBootstrap = ( URL, WebSocket,
                                   RemovableChannelHandler,
                                   ChannelHandler ) -> ClientBootstrap
  
  /// This could later be used to register custom bootstraps for say TLS.
  static var schemeToBootstrap : [ String : WebSocketBootstrap ] = [
    "ws": makePlainClientBootstrap
  ]

  /**
   * Generate a random 16-byte key and base64 encode it per RFC 6455.
   */
  private static func generateRequestKey() -> String {
    var data = Data()
    data.reserveCapacity(16)
    withUnsafeBytes(of: UInt64.random(in: .min ... .max)) {
      data.append(contentsOf: $0)
    }
    withUnsafeBytes(of: UInt64.random(in: .min ... .max)) {
      data.append(contentsOf: $0)
    }
    return data.base64EncodedString()
  }
  
  func bootstrapForURL(_ url: URL) -> ClientBootstrap? {
    guard let scheme = url.scheme?.lowercased() else {
      log.error("Missing scheme in WebSocket URL:", url)
      return nil
    }
    guard let bootstrap = WebSocket.schemeToBootstrap[scheme] else {
      log.warn("Unsupported WebSocket scheme '\(scheme)' in URL:", url)
      return nil
    }

    let requestKey = WebSocket.generateRequestKey()
    let host       = hostHeaderValue(from: url)
    let path       = url.path.isEmpty ? "/" : url.path
    let httpHandler = HTTPHandler(path: path, host: host, requestKey: requestKey,
                                  ws: self)
    return bootstrap(url, self, httpHandler, WebSocketConnection(self))
  }

  /**
   * Generate the Host header value from a URL (host:port, omitting default
   * ports).
   */
  private func hostHeaderValue(from url: URL) -> String {
    guard let host = url.host else { return "" }
    guard let port = url.port else { return host }
    let defaultPort = defaultPortForScheme(url.scheme)
    if port == defaultPort { return host }
    return "\(host):\(port)"
  }
  
  static func makePlainClientBootstrap(url         : URL, for ws: WebSocket,
                                       httpHandler : RemovableChannelHandler,
                                       wsHandler   : ChannelHandler)
              -> ClientBootstrap
  {
    guard let handler = httpHandler as? HTTPHandler else {
      fatalError("Expected HTTPHandler")
    }
    let requestKey = handler.requestKey
    let bootstrap = ClientBootstrap(group: MacroCore.shared.fallbackEventLoop())
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .channelInitializer { channel in
        let upgrader = NIOWebSocketClientUpgrader(
          requestKey: requestKey,
          upgradePipelineHandler: { channel, _ in
            channel.pipeline
                   .addHandler(wsHandler, name: WebSocket.webSocketHandlerName)
          }
        )
        
        let config = NIOHTTPClientUpgradeConfiguration(
          upgraders: [ upgrader ],
          completionHandler: { _ in
            _ = channel.pipeline.removeHandler(httpHandler)
          }
        )

        return channel.pipeline
          .addHTTPClientHandlers(withClientUpgrade: config)
          .flatMap {
            channel.pipeline
                   .addHandler(httpHandler, name: WebSocket.httpHandlerName)
          }
      }
    return bootstrap
  }
}

fileprivate func defaultPortForScheme(_ scheme: String?) -> Int? {
  guard let scheme = scheme else { return nil }
  switch scheme {
    case "ws"    : return 80
    case "wss"   : return 443
    case "http"  : return 80
    case "https" : return 443
    default      : return nil
  }
}
