//
//  OutgoingMessage.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.Channel
import struct   NIOHTTP1.HTTPHeaders
import struct   Logging.Logger
import class    MacroCore.WritableByteStream
import protocol MacroCore.WritableStreamType
import protocol MacroCore.WritableByteStreamType
import protocol MacroCore.ListenerType
import class    MacroCore.ErrorEmitter
import enum     MacroCore.EventListenerSet
import func     MacroCore.nextTick
import struct   MacroCore.Buffer
import struct   MacroCore.EnvironmentValues
import protocol MacroCore.EnvironmentValuesHolder

/**
 * Baseclass for `ServerResponse` and `ClientRequest`.
 *
 * Hierarchy:
 *
 *   WritableStreamBase
 *     WritableByteStreamBase
 *     * OutgoingMessage
 *         ServerResponse
 *         ClientRequest
 */
open class OutgoingMessage: WritableByteStream,
                            WritableStreamType, WritableByteStreamType
{

  public enum StreamState: Equatable {
    case ready
    case isEnding
    case finished
  }

  public var log         : Logger
  public var headers     = HTTPHeaders()
  public var headersSent = false
  public var sendDate    = true

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
  public lazy var environment = MacroCore.EnvironmentValues.empty

  public internal(set) var socket : Channel?

  @available(*, deprecated, message: "Please use the regular `log` w/ `.error`")
  @inlinable
  override open var errorLog : Logger { return log } // this was a mistake

  public var state = StreamState.ready

  override open var writableFinished : Bool { return state == .finished }
  override open var writableEnded    : Bool {
    return state == .isEnding || state == .finished
  }
  @inlinable
  override open var writable : Bool { return !writableEnded  }

  public init(unsafeChannel channel: Channel?, log: Logger) {
    self.socket = channel
    self.log    = log
    super.init()
  }

  // MARK: - End Stream
  
  open func end() {
    assertionFailure("subclass responsibility: \(#function)")
  }
  
  // MARK: - Error Handling

  open func handleError(_ error: Error) {
    log.error("\(error)")
    _ = socket?.close() // TBD
    socket = nil
    emit(error: error)
    finishListeners.emit()
  }
  
  // MARK: - WritableByteStream
  
  @discardableResult
  open func write(_ bytes: Buffer, whenDone: @escaping () -> Void) -> Bool {
    assertionFailure("subclass responsibility: \(#function)")
    whenDone()
    return false
  }
  @discardableResult @inlinable
  open func write(_ string: String, whenDone: @escaping () -> Void = {}) -> Bool
  {
    guard writableCorked || socket != nil else { whenDone(); return false }
    return write(Buffer(string), whenDone: whenDone)
  }
  
}

extension OutgoingMessage: EnvironmentValuesHolder  {}
extension OutgoingMessage: HTTPMutableHeadersHolder {}
