//
//  ReadableByteStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer

/**
 * A non-generic materialized variant of `ReadableStreamType`
 */
public protocol ReadableByteStreamType: ErrorEmitterType {
  
  typealias ByteBuffer = NIO.ByteBuffer

  var  readableHighWaterMark : Int  { get }
  var  readableLength        : Int  { get }
  var  readableEnded         : Bool { get }
  var  readableFlowing       : Bool { get }

  func push(_ bytes: ByteBuffer)

  func read(_ count: Int?) -> ByteBuffer
  func read()              -> ByteBuffer

  // MARK: - Events
  
  @discardableResult
  func onceEnd(execute: @escaping () -> Void) -> Self
  
  @discardableResult
  func onEnd(execute: @escaping () -> Void) -> Self

  @discardableResult
  func onceReadable(execute: @escaping () -> Void) -> Self
  
  @discardableResult
  func onReadable(execute: @escaping () -> Void) -> Self

  @discardableResult
  func onceData(execute: @escaping ( ByteBuffer ) -> Void) -> Self
  
  @discardableResult
  func onData(execute: @escaping ( ByteBuffer ) -> Void) -> Self
}
