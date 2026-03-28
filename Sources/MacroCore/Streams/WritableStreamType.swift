//
//  WritableStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
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

  /// Fires after all data has been flushed but before
  /// `finish`. Like `finish`, it fires at most once.
  @discardableResult
  func oncePrefinish(execute: @escaping () -> Void) -> Self

  @discardableResult
  func onPrefinish(execute: @escaping () -> Void) -> Self

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
  
  @discardableResult
  @inlinable
  func onPrefinish(execute: @escaping () -> Void) -> Self {
    return oncePrefinish(execute: execute)
  }

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
    write(payload) { self.end() }
  }
}

// MARK: - Deprecated Properties

public extension WritableStreamType {
  
  @available(*, deprecated, message: "please use `writableEnded`")
  var finished : Bool { return writableEnded }
}
