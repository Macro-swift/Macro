//
//  ReadableStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public protocol ReadableStreamType: ErrorEmitterType {
  
  associatedtype ReadablePayload
  
  var  readableHighWaterMark : Int  { get }
  var  readableLength        : Int  { get }
  var  readableEnded         : Bool { get }
  var  readableFlowing       : Bool { get }

  func push(_ bytes: ReadablePayload?)

  func read(_ count: Int?) -> ReadablePayload
  func read()              -> ReadablePayload

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
  func onceData(execute: @escaping ( ReadablePayload ) -> Void) -> Self
  
  @discardableResult
  func onData(execute: @escaping ( ReadablePayload ) -> Void) -> Self
}

public enum ReadableError: Swift.Error {
  case readableEnded
}

// MARK: - Default Implementations

public extension ReadableStreamType {
  func read() -> ReadablePayload { return read(nil) }
}
