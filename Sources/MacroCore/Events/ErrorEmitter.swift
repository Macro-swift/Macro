//
//  ErrorEmitter.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public protocol ErrorEmitterType {
  
  typealias ErrorCB = ( Error ) -> Void

  @discardableResult func onError  (execute: @escaping ErrorCB) -> Self
  @discardableResult func onceError(execute: @escaping ErrorCB) -> Self
}

public protocol ErrorEmitterTarget {
  
  func emit(error: Error)
}


import struct Logging.Logger

/**
 * A reusable base class for objects which can emit errors.
 */
open class ErrorEmitter : ErrorEmitterType, ErrorEmitterTarget {
  
  @inlinable
  public var core : MacroCore { return MacroCore.shared }
  
  @inlinable
  open var errorLog : Logger { return console.logger }

  public init() {}
  
  // MARK: - ErrorEmitter
  
  public final var errorListeners = EventListenerSet<Error>()
  
  @inlinable
  open func emit(error: Error) {
    if errorListeners.isEmpty {
      let objectInfo = "\(type(of: self)):\(ObjectIdentifier(self))"
      errorLog.error("[\(objectInfo)] Error not handled: \(error)")
    }
    else {
      errorListeners.emit(error)
    }
  }
  
  @inlinable
  @discardableResult
  public func onError(execute: @escaping ErrorCB) -> Self {
    errorListeners += execute
    return self
  }
  
  @inlinable
  @discardableResult
  public func onceError(execute: @escaping ErrorCB) -> Self {
    errorListeners.once(execute)
    return self
  }
}
