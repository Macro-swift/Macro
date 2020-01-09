//
//  WritableByteStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * A non-generic materialized variant of `WritableStreamType`
 */
public protocol WritableByteStreamType: ErrorEmitterType {
  
  var  writableEnded : Bool { get }
  
  // TBD: Pass `Result<Value, Error>` to done callback?
  //      Yes, and provide those w/o args as wrappers.
  
  @discardableResult
  func write(_ bytes  : Buffer, whenDone : @escaping () -> Void) -> Bool
  @discardableResult
  func write(_ string : String, whenDone : @escaping () -> Void) -> Bool

  // MARK: - Events
  // TODO: drain/close
  
  @discardableResult
  func onceFinish(execute: @escaping () -> Void) -> Self
  
  /// `onFinish` is the same like `onceFinish` (only ever finishes once)
  @discardableResult
  func onFinish(execute: @escaping () -> Void) -> Self
}


public extension WritableStreamType where WritablePayload == Buffer {
  
  @inlinable
  @discardableResult
  func write(_ string: String, whenDone: @escaping () -> Void = {}) -> Bool {
    return write(Buffer(string), whenDone: whenDone)
  }
}

import struct Foundation.Data

public extension WritableStreamType where WritablePayload == Buffer {
  
  @inlinable
  @discardableResult
  func write(_ data: Data, whenDone: @escaping () -> Void = {}) -> Bool {
    return write(Buffer(data), whenDone: whenDone)
  }
}
