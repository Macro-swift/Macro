//
//  WebSocket.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Foundation.Data
import class  Foundation.JSONEncoder
import class  Foundation.JSONDecoder
import class  Foundation.JSONSerialization
import struct Logging.Logger
import class  MacroCore.ErrorEmitter
import enum   MacroCore.EventListenerSet

// during dev
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
  }
  
  open                var log     : Logger
  public private(set) var channel : Channel?
  
  /**
   * Initialize the WebSocket with a fully setup and configured NIO `Channel`.
   *
   * Used by the server.
   */
  @usableFromInline
  init(_ channel: Channel, log: Logger = .init(label: "μ.ws")) {
    self.channel = channel
    self.log     = log
    super.init()
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
      let data = try JSONSerialization.data(withJSONObject: message,
                                            options: [ .fragmentsAllowed ])
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
        let json = try JSONSerialization
                        .jsonObject(with: data, options: .fragmentsAllowed)
        _messageListeners.emit(json)
      }
      catch {
        emit(error: error)
      }
    }
  }
}
