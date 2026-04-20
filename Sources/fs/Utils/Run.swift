//
//  Run.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.EventLoop
import class    NIO.MultiThreadedEventLoopGroup
import class    NIO.NIOThreadPool
import enum     NIO.ChannelError
import class    MacroCore.MacroCore
import enum     MacroCore.process

extension FileSystemModule {

  /**
   * Execute a closure on the I/O thread pool.
   *
   * Example:
   * ```swift
   * fs.run {
   *   ... blocking operations, e.g. againt PostgreSQL ...
   * } then: { hash in
   *   res.json([ "results": results ])
   * }
   * ```
   *
   * - Parameters:
   *   - eventLoop: The event loop to deliver the result on, or `nil` to use
   *                the current or default loop.
   *   - execute:   The blocking closure to run on the thread pool.
   *   - yield:     The callback receiving the result on the event loop.
   */
  @inlinable 
  static func run<R>(on eventLoop : EventLoop? = nil,
                     _    execute : @escaping () -> R,
                     then   yield : @escaping ( R ) -> Void)
  {
    let module = MacroCore.shared.retain()
    let loop   = module.fallbackEventLoop(eventLoop)
    threadPool.submit { shouldRun in
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        process.emitWarning("Thread pool not active anymore, yield not called",
                            name: "fs.run")
        assertionFailure("Inactive thread pool?")
        return loop.execute { module.release() } 
      }
      let result = execute()
      loop.execute {
        yield(result)
        module.release()
      }
    }
  }

  /**
   * Execute a throwing closure on the I/O thread pool.
   *
   * If the closure throws, the error is passed as the first argument to
   * `then` and `R` will be `nil`.
   *
   * Example:
   * ```swift
   * fs.run {
   *   ... try blocking operations, e.g. againt PostgreSQL ...
   * } then: { error, hash in
   *   res.json([ "hash": hash ])
   * }
   * ```
   *
   * - Parameters:
   *   - eventLoop: The event loop to deliver the result on, or `nil` to use
   *                the current or default loop.
   *   - execute:   The throwing closure to run on the thread pool.
   *   - yield:     The callback receiving the error and/or result on the loop.
   */
  @inlinable
  static func run<R>(on eventLoop : EventLoop? = nil,
                     _    execute : @escaping () throws -> R,
                     then   yield : @escaping ( Swift.Error?, R? ) -> Void)
  {
    let module = MacroCore.shared.retain()
    let loop   = module.fallbackEventLoop(eventLoop)
    threadPool.submit { shouldRun in
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        return loop.execute {
          assertionFailure("Inactive thread pool?")
          yield(ChannelError.ioOnClosedChannel, nil)
          module.release()
        }
      }
      do {
        let result = try execute()
        loop.execute {
          yield(nil, result)
          module.release()
        }
      }
      catch {
        loop.execute {
          yield(error, nil)
          module.release()
        }
      }
    }
  }

  // MARK: - Async/Await

  #if swift(>=5.9) && canImport(_Concurrency)

  /**
   * Execute a blocking closure on the I/O thread pool and return the result.
   *
   * Example:
   * ```swift
   * let results = await fs.run { .. blocking work ... }
   * ```
   *
   * - Parameters:
   *   - execute: The blocking closure to run on the thread pool.
   * - Returns:   The value returned by `execute`.
   */
  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  @inlinable
  static func run<R>(_ execute: @escaping () -> R) async -> R {
    await withCheckedContinuation { continuation in
      run(execute, then: { continuation.resume(returning: $0) })
    }
  }

  /**
   * Execute a throwing blocking closure on the I/O thread pool.
   *
   * Example:
   * ```swift
   * let results = try await fs.run {
   *   ... try hit PG ...
   * }
   * ```
   *
   * - Parameter
   *   - execute: The throwing closure to run on the thread pool.
   * - Returns:   The value returned by `execute`.
   * - Throws:    Rethrows the error from `execute`, or
   *              `ChannelError.ioOnClosedChannel` if the pool is shut down.
   */
  @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
  @inlinable
  static func run<R>(_ execute: @escaping () throws -> R) async throws -> R {
    try await withCheckedThrowingContinuation { continuation in
      run(execute) { error, result in
        if let result {
          continuation.resume(returning: result)
        }
        else {
          continuation.resume(throwing: error ?? ChannelError.ioOnClosedChannel)
        }
      }
    }
  }

  #endif
}
