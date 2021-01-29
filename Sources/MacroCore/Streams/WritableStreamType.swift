//
//  WritableStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public protocol WritableStreamType: ErrorEmitterType, ErrorEmitterTarget {

  associatedtype WritablePayload

  var  writableHighWaterMark : Int  { get }
  var  writableEnded         : Bool { get }

  @discardableResult
  func write(_ payload: WritablePayload, whenDone : @escaping () -> Void)
       -> Bool
  
  func end()
  
  // MARK: - Events
  // TODO: drain/close
  
  @discardableResult
  func onceFinish(execute: @escaping () -> Void) -> Self
  
  /// `onFinish` is the same like `onceFinish` (only ever finishes once)
  @discardableResult
  func onFinish(execute: @escaping () -> Void) -> Self
}

public enum WritableError: Swift.Error {
  case writableEnded
}

// MARK: - Default Implementations

public extension WritableStreamType {
  
  /// `onFinish` is the same like `onceFinish` (only ever finishes once)
  @discardableResult
  @inlinable
  func onFinish(execute: @escaping () -> Void) -> Self {
    return onceFinish(execute: execute)
  }
}

public extension WritableStreamType {
  
  @inlinable
  func end(_ payload: WritablePayload) {
    write(payload) { end() }
  }
}

// MARK: - Deprecated Properties

public extension WritableStreamType {
  
  @available(*, deprecated, message: "please use `writableEnded`")
  var finished : Bool { return writableEnded }
}
