//
//  OutgoingMessage.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.Channel
import struct   NIO.ByteBuffer
import struct   NIOHTTP1.HTTPHeaders
import struct   Logging.Logger
import class    MacroCore.WritableByteStream
import protocol MacroCore.WritableStreamType
import protocol MacroCore.WritableByteStreamType
import protocol MacroCore.ListenerType
import class    MacroCore.ErrorEmitter
import enum     MacroCore.EventListenerSet
import func     MacroCore.nextTick

/**
 * Baseclass for `ServerResponse` and `ClientRequest`.
 */
open class OutgoingMessage: WritableByteStream,
                            WritableStreamType, WritableByteStreamType
{

  enum StreamState: Equatable {
    case ready
    case isEnding
    case finished
  }

  public let log         : Logger
  public var headers     = HTTPHeaders()
  public var headersSent = false
  public var sendDate    = true
  public var extra       = [ String : Any ]()
  
  public internal(set) var socket : Channel?

  @inlinable
  override open var errorLog : Logger { return log }

  var state = StreamState.ready

  override open var writableFinished : Bool { return state == .finished }
  override open var writableEnded    : Bool {
    return state == .isEnding || state == .finished
  }
  @inlinable
  override open var writable : Bool { return !writableEnded  }

  public init(channel: Channel, log: Logger) {
    self.socket = channel
    self.log    = log
    super.init()
  }

  // MARK: - End Stream
  
  open func end() {
    assertionFailure("subclass responsibility: \(#function)")
  }
  
  // MARK: - Error Handling

  func handleError(_ error: Error) {
    log.error("\(error)")
    _ = socket?.close() // TBD
    socket = nil
    emit(error: error)
    finishListeners.emit()
  }
  
  // MARK: - WritableByteStream
  
  @discardableResult
  open func write(_ bytes: ByteBuffer, whenDone: @escaping () -> Void) -> Bool {
    assertionFailure("subclass responsibility: \(#function)")
    whenDone()
    return false
  }
  @discardableResult @inlinable
  open func write(_ string: String, whenDone: @escaping () -> Void = {}) -> Bool
  {
    guard let channel = socket else { whenDone(); return false }
    var byteBuffer = channel.allocator.buffer(capacity: string.count)
    byteBuffer.writeString(string)
    return write(byteBuffer, whenDone: whenDone)
  }
  
}

extension OutgoingMessage: HTTPMutableHeadersHolder {}
