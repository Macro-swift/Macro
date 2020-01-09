//
//  ReadableByteStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * A non-generic materialized variant of `ReadableStreamType`
 */
public protocol ReadableByteStreamType: ErrorEmitterType {

  var  readableHighWaterMark : Int  { get }
  var  readableLength        : Int  { get }
  var  readableEnded         : Bool { get }
  var  readableFlowing       : Bool { get }

  func push(_ bytes: Buffer)

  func read(_ count: Int?) -> Buffer
  func read()              -> Buffer

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
  func onceData(execute: @escaping ( Buffer ) -> Void) -> Self
  
  @discardableResult
  func onData(execute: @escaping ( Buffer ) -> Void) -> Self
}
