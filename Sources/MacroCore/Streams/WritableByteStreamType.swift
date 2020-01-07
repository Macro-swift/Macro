//
//  WritableByteStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer

/**
 * A non-generic materialized variant of `WritableStreamType`
 */
public protocol WritableByteStreamType: ErrorEmitterType {

  typealias ByteBuffer = NIO.ByteBuffer
  
  var  writableEnded : Bool { get }
  
  // TBD: Pass `Result<Value, Error>` to done callback?
  //      Yes, and provide those w/o args as wrappers.
  
  @discardableResult
  func write(_ bytes  : ByteBuffer, whenDone : @escaping () -> Void)
       -> Bool
  @discardableResult
  func write(_ string : String,     whenDone : @escaping () -> Void)
       -> Bool

  // MARK: - Events
  // TODO: drain/close
  
  @discardableResult
  func onceFinish(execute: @escaping () -> Void) -> Self
  
  /// `onFinish` is the same like `onceFinish` (only ever finishes once)
  @discardableResult
  func onFinish(execute: @escaping () -> Void) -> Self
}


import struct NIO.ByteBufferAllocator

public extension WritableStreamType where WritablePayload == ByteBuffer {
  
  @inlinable
  @discardableResult
  func write(_ string: String, whenDone: @escaping () -> Void = {}) -> Bool {
    var byteBuffer = ByteBufferAllocator().buffer(capacity: string.count)
    byteBuffer.writeString(string)
    return write(byteBuffer, whenDone: whenDone)
  }
}

import struct Foundation.Data

public extension WritableStreamType where WritablePayload == ByteBuffer {
  
  @inlinable
  @discardableResult
  func write(_ data: Data, whenDone: @escaping () -> Void = {}) -> Bool {
    var byteBuffer = ByteBufferAllocator().buffer(capacity: data.count)
    byteBuffer.writeBytes(data)
    return write(byteBuffer, whenDone: whenDone)
  }
}
