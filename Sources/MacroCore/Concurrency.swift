//
//  Concurrency.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2025 ZeeZide GmbH. All rights reserved.
//

#if swift(>=5.9) && canImport(_Concurrency)
// We just do it for Swift 5.9+, gives us parameter packs, making things more
// convenient.

import NIO

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension MacroCore {

  /**
   * Execute an async closure while keeping the execution environment alive.
   * 
   * - Parameters:
   *   - args:      Optional arguments.
   *   - body:      The asynchronous closure to call.
   */
  @inlinable
  func `task`<each A>(_ args : repeat each A,
                      body   : @escaping (repeat each A) async -> Void)
  {
    retain()
    Task {
      await body(repeat each args)
      self.release()
    }
  }
  
  
  /**
   * Execute an async closure while keeping the execution environment alive.
   * 
   * This captures the value returned by the asynchronous function and invokes
   * the callback on the given or default eventloop.
   * 
   * - Parameters:
   *   - eventLoop: The eventloop to run the yield closure on, or nil to use the
   *                current or default loop.
   *   - args:      Optional arguments.
   *   - body:      The asynchronous closure to call.
   *   - yield:     The callback which receives the value of the closure.
   */
  @inlinable
  func `task`<each A, R>(on eventLoop : EventLoop? = nil,
                         _ args : repeat each A,
                         body   : @escaping (repeat each A) async -> R,
                         yield  : @escaping ( R ) -> Void)
  {
    retain()
    
    let loop = eventLoop
            ?? MultiThreadedEventLoopGroup.currentEventLoop
            ?? eventLoopGroup.next()
    Task {
      let value = await body(repeat each args)
      loop.execute {
        yield(value)
      }
      self.release()
    }
  }
  
  /**
   * Execute an async, throwing closure while keeping the execution environment 
   * alive.
   * 
   * This captures the value returned by the asynchronous function and invokes
   * the callback on the given or default eventloop.
   * 
   * - Parameters:
   *   - eventLoop: The eventloop to run the yield closure on, or nil to use the
   *                current or default loop.
   *   - args:      Optional arguments.
   *   - body:      The asynchronous closure to call.
   *   - yield:     The callback which receives the value of the closure.
   */
  @inlinable
  func `task`<each A, R>(on eventLoop : EventLoop? = nil,
                         _ args : repeat each A,
                         body   : @escaping (repeat each A) async throws -> R,
                         yield  : @escaping ( Swift.Error?, R? ) -> Void)
  {
    retain()
    
    let loop = eventLoop
            ?? MultiThreadedEventLoopGroup.currentEventLoop
            ?? eventLoopGroup.next()
    Task {
      do {
        let value = try await body(repeat each args)
        loop.execute { yield(nil, value) }
      }
      catch {
        loop.execute { yield(error, nil) }
      }
      self.release()
    }
  }
}

#endif
