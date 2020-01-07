//
//  WritableStreamBase.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
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
 * - the subclass should to conform to `WritableStreamType`
 */
open class WritableStreamBase<WritablePayload>: ErrorEmitter {

  open   var writableHighWaterMark = 4096
  public var finishListeners       = EventListenerSet<Void>()
  public var drainListeners        = EventListenerSet<Void>()
  
  open var writableEnded : Bool {
    get {
      fatalError("subclass responsibility \(#function)")
    }
  }
  open var writableFinished : Bool {
    get {
      fatalError("subclass responsibility \(#function)")
    }
  }
  open var writableCorked : Bool { return false }
  open var writable       : Bool { return !writableFinished }

  // MARK: - Init

  #if DEBUG && false // cycle debugging
  public override init() {
    super.init()
    print("INIT:\(ObjectIdentifier(self)) \(type(of:self))")
  }
  deinit {
    print("DEINIT:\(ObjectIdentifier(self)) \(type(of:self))")
  }
  #endif
  
  
  // MARK: - Listeners
  
  @discardableResult
  open func onceFinish(execute: @escaping () -> Void) -> Self {
    finishListeners.once(immediate: writableEnded, execute)
    return self
  }
  @discardableResult
  open func onFinish(execute: @escaping () -> Void) -> Self {
    onceFinish(execute: execute)
    return self
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
