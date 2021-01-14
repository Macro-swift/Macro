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
  
  enum WebSocketError: Swift.Error {
    case connectionNotOpen
    case upgradeFailed       (status: Int?)
    case invalidURL          (String)
    case unsupportedURLScheme(URL)
    case missingPortInURL    (URL)
  }
  
  open                var log     : Logger
  public private(set) var channel : Channel?

  public var isConnected : Bool { return channel != nil }

  private var didRetain = false

  /**
   * Initialize the WebSocket with a fully setup and configured NIO `Channel`.
   *
   * Used by the server.
   */
  @usableFromInline
  init(_ channel: Channel?, log: Logger? = nil) {
    self.channel = channel
    self.log     = log ?? .init(label: "μ.ws")
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
  func emitPong() {
    _pongListeners.emit()
  }
  func emitOpen() {
    _openListeners.emit(self)
  }

  func close() {
    _closeListeners.emit( () )
    guard channel != nil else { return }
    _messageListeners.removeAll()
    _dataListeners   .removeAll()
    _closeListeners  .removeAll()
    
    // TBD: This probably needs to be smarter, send FIN packets and such.
    channel?.close(mode: .all, promise: nil)
    channel = nil

    if didRetain { didRetain = false; core.release() }
  }
  
  
  // MARK: - Sending Data

  @inlinable
  public func send<T: Encodable>(_ message: T) {
    do {
      let data = try JSONEncoder().encode(message)
      send(data)
    }
    catch {
      emit(error: error)
    }
  }

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
      send(data)
    }
    catch {
      emit(error: error)
    }
  }

  @usableFromInline
  func send(_ data: Data) {
    guard let channel = channel else {
      return emit(error: WebSocketError.connectionNotOpen)
    }
    
    var buffer = channel.allocator.buffer(capacity: data.count)
    buffer.writeBytes(data)
    
    let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
    channel.writeAndFlush(frame)
           .whenFailure(self.emit(error:))
  }
  
  
  // MARK: - Receiving Data
  
  func processIncomingData(_ data: Data) {
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

    var ws   : WebSocket?
    var path : String
    
    init(path: String, ws: WebSocket) {
      self.path = path
      self.ws   = ws
    }
    
    public func channelActive(context: ChannelHandlerContext) {
      let req = HTTPRequestHead(version : .init(major: 1, minor: 1),
                                method  : .GET, uri: path, headers: [
                                  "Content-Type"   : "application/octet-stream",
                                  "Content-Length" : "0"
                                ])
      context.write(self.wrapOutboundOut(.head(req)), promise: nil)
      
      let body = HTTPClientRequestPart.body(.byteBuffer(ByteBuffer()))
      context.write(self.wrapOutboundOut(body), promise: nil)
      
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
  static var schemeToBootstrap : [String : WebSocketBootstrap ] = [
    "ws": makePlainClientBootstrap
  ]
  
  func bootstrapForURL(_ url: URL) -> ClientBootstrap? {
    guard let scheme = url.scheme?.lowercased() else {
      log.error("Missing scheme in WebSocket URL:", url)
      return nil
    }
    guard let bootstrap = WebSocket.schemeToBootstrap[scheme] else {
      log.warn("Unsupported WebSocket scheme '\(scheme)' in URL:", url)
      return nil
    }
    
    return bootstrap(url, self,
                     HTTPHandler(path: url.path, ws: self),
                     WebSocketConnection(self))
  }
  
  static func makePlainClientBootstrap(url         : URL, for ws: WebSocket,
                                       httpHandler : RemovableChannelHandler,
                                       wsHandler   : ChannelHandler )
              -> ClientBootstrap
  {
    // TODO: Ask Cory what the requestKey is and how to calculate it :-)
    // It's binary but doesn't seem to be the WebSocket GUID mentioned
    // (258EAFA5-E914-47DA-95CA-C5AB0DC85B11):
    // 39 f4 b4 c0 36 93 e4 da 31 17 68 2a 9b b6 63 d9 8b 5e b7 33
    // Well, there is:
    // https://stackoverflow.com/questions/18265128/what-is-sec-websocket-key-for
    let requestKey = "OfS0wDaT5NoxF2gqm7Zj2YtetzM="
    let bootstrap = ClientBootstrap(group: MacroCore.shared.fallbackEventLoop())
      .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .channelInitializer { channel in
        let upgrader = NIOWebSocketClientUpgrader(
          requestKey: requestKey,
          upgradePipelineHandler: { channel, _ in
            channel.pipeline
                   .addHandler(wsHandler, name: WebSocket.webSocketHandlerName)
              .always { result in
print("UPGRADE ADDING:", channel.pipeline, result)
              }
          }
        )
        
        let config = NIOHTTPClientUpgradeConfiguration(
          upgraders: [ upgrader ],
          completionHandler: { _ in
            _ = channel.pipeline.removeHandler(httpHandler) //, promise: nil)
              .always { result in
                print("DID COMPLETE:", channel.pipeline, result)
              }
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
