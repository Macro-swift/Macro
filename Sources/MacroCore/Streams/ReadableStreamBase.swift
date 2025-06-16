//
//  ReadableStreamBase.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

/**
 * Superclass for readable streams.
 *
 * Note: This does not conform to `ReadableStreamType` yet, because this base
 *       class does not implement the buffer in a generic way.
 *
 * If a byte stream is being implemented, consider using the
 * `ReadableByteStream` base class.
 *
 * ## Subclassing
 *
 * - `readableLength` MUST be overridden
 * - the subclass should to conform to `ReadableStreamType`
 * - the `onData` setup functions need to be implemented
 *
 * Hierarchy:
 *
 * - ErrorEmitter
 *   * ReadableStreamBase
 *     - ReadableByteStream
 *       - IncomingMessage
 */
open class ReadableStreamBase<ReadablePayload>: ErrorEmitter {

  open   var readableHighWaterMark = 16 * 1024
  public var readableEnded         = false
  open   var readableFlowing       = false

  #if DEBUG && false // cycle debugging
  public override init() {
    super.init()
    let id = String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    print("INIT:0x\(id) \(type(of:self))")
  }
  deinit {
    let id = String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    print("DEINIT:0x\(id) \(type(of:self))")
  }
  #else
  public override init() {
    super.init()
  }
  #endif
  
  @inlinable
  open var readableLength : Int {
    assertionFailure("subclass responsibility: \(#function)")
    return 0
  }

  public var dataListeners         = EventListenerSet<ReadablePayload>()
  public var endListeners          = EventListenerSet<Void>()
  public var readableListeners     = EventListenerSet<Void>()

  @discardableResult @inlinable
  open func onceEnd(execute: @escaping () -> Void) -> Self {
    if readableEnded {
      nextTick(execute)
      return self
    }
    else {
      endListeners.once(execute); return self
    }
  }
  
  /// `onEnd` is the same like `onceEnd`
  @discardableResult @inlinable
  open func onEnd(execute: @escaping () -> Void) -> Self {
    return onceEnd(execute: execute)
  }
  
  @discardableResult @inlinable
  open func onceReadable(execute: @escaping () -> Void) -> Self {
    if readableLength > 0 { execute() }
    else {
      readableListeners.once(execute)
      readableFlowing = true
    }
    return self
  }
  
  @discardableResult
  @inlinable
  open func onReadable(execute: @escaping () -> Void) -> Self {
    readableListeners.add(execute)
    if readableLength > 0 { execute() }
    readableFlowing = true
    return self
  }
}
