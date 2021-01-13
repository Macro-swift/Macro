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

open class WebSocket: ErrorEmitter {
  
  // TODO: implement me
  
  enum WebSocketError: Swift.Error {
    case connectionNotOpen
  }
  
  var log     : Logger
  var channel : Channel?
  
  @usableFromInline
  init(_ channel: Channel, log: Logger = .init(label: "μ.ws")) {
    self.channel = channel
    self.log     = log
    super.init()
  }
  
  
  // MARK: - Event Handlers

  private var _closeListeners   = EventListenerSet<()>()
  private var _messageListeners = EventListenerSet<( Any )>()
  private var _dataListeners    = EventListenerSet<Data>()

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
  func send<T: Encodable>(_ message: T) {
    do {
      let data = try JSONEncoder().encode(message)
      send(data)
    }
    catch {
      emit(error: error)
    }
  }

  @inlinable
  func send(_ message: Any) {
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
