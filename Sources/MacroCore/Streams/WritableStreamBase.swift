//
//  WritableStreamBase.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

/**
 * Superclass for writable streams.
 *
 * Note: This does not conform to `WritableStreamType` yet, because this base
 *       class does not implement the buffer in a generic way.
 *
 * If a byte stream is being implemented, consider using the
 * `WritableByteStream` base class.
 *
 * ## Subclassing
 *
 * - the subclass should to conform to ``WritableStreamType``
 */
open class WritableStreamBase<WritablePayload>: ErrorEmitter {

  open   var writableHighWaterMark = 4096
  public var prefinishListeners    = EventListenerSet<Void>()
  public var finishListeners       = EventListenerSet<Void>()
  public var drainListeners        = EventListenerSet<Void>()
  
  open var writableEnded : Bool {
    fatalError("subclass responsibility \(#function)")
  }
  open var writableFinished : Bool {
    fatalError("subclass responsibility \(#function)")
  }
  @inlinable open var writableCorked : Bool { return false }
  @inlinable open var writable       : Bool { return !writableFinished }

  // MARK: - Init

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
  #endif
  
  
  // MARK: - Listeners
  
  @discardableResult
  open func oncePrefinish(execute: @escaping () -> Void) -> Self {
    prefinishListeners.once(immediate: writableEnded, execute)
    return self
  }
  @discardableResult
  open func onPrefinish(execute: @escaping () -> Void) -> Self {
    return oncePrefinish(execute: execute)
  }

  @discardableResult
  open func onceFinish(execute: @escaping () -> Void) -> Self {
    finishListeners.once(immediate: writableEnded, execute)
    return self
  }
  @discardableResult
  open func onFinish(execute: @escaping () -> Void) -> Self {
    return onceFinish(execute: execute)
  }
  
  @discardableResult
  open func onceDrain(execute: @escaping () -> Void) -> Self {
    // TBD: does drain need an immediate mode if the buffer is empty?
    drainListeners.once(execute)
    return self
  }
  @discardableResult
  open func onDrain(execute: @escaping () -> Void) -> Self {
    drainListeners.add(execute)
    return self
  }
}
