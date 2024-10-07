//
//  Concat.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

/**
 * Returns a stream in the spirit of the Node `concat-stream` module:
 *
 *   https://github.com/maxogden/concat-stream
 *
 * Be careful w/ using that. You don't want to baloon payloads in memory!
 *
 * Usage:
 * ```
 * request | concat { buffer in
 *   console.log("The size of the request body is:", buffer.count)
 * }
 * ```
 *
 * Pushes a ``ConcatError`` if the maximum size was exceeded.
 *
 * - Parameters:
 *   - maximumSize: The maximum size of the request body. Can be configured
 *                  using the `macro.concat.maxsize` environment variable.
 *   - yield:       A closure called with the loaded data (a ``Buffer``).
 * - Returns: The ``ConcatByteStream``.
 */
@inlinable
public func concat(maximumSize: Int = _defaultConcatMaximumSize,
                   yield: @escaping ( Buffer ) -> Void) -> ConcatByteStream
{
  let stream = ConcatByteStream(maximumSize: maximumSize)
  return stream.onceFinish {
    let result = stream.writableBuffer
    stream.writableBuffer = MacroCore.shared.emptyBuffer
    yield(result)
  }
}

/**
 * Returns a stream in the spirit of the Node `concat-stream` module:
 *
 *   https://github.com/maxogden/concat-stream
 *
 * Be careful w/ using that. You don't want to baloon payloads in memory!
 *
 * Usage:
 * ```
 * request | concat { buffer in
 *   console.log("The size of the request body is:", buffer.count)
 * }
 * ```
 *
 * Pushes a ``ConcatError`` if the maximum size was exceeded.
 *
 * - Parameters:
 *   - maximumSize: The maximum size of the request body. Can be configured
 *                  using the `macro.concat.maxsize` environment variable.
 *   - yield:       A closure called with the loaded data (a ``Buffer``).
 * - Returns: The ``ConcatByteStream``.
 */
@inlinable
public func concat(maximumSize: Int = _defaultConcatMaximumSize,
                   yield: @escaping ( Buffer ) throws -> Void)
            -> ConcatByteStream
{
  let stream = ConcatByteStream(maximumSize: maximumSize)
  return stream.onceFinish {
    defer { stream.writableBuffer = MacroCore.shared.emptyBuffer }
    do {
      try yield(stream.writableBuffer)
    }
    catch {
      stream.emit(error: error)
    }
  }
}

/**
 * A stream in the spirit of the Node `concat-stream` module:
 *
 *   https://github.com/maxogden/concat-stream
 *
 * Be careful w/ using that. You don't want to baloon payloads in memory!
 *
 * Create those objects using the `concat` function.
 */
public class ConcatByteStream: WritableByteStream,
                               WritableByteStreamType, WritableStreamType,
                               CustomStringConvertible
{
  // TBD: This should be duplex? Or is the duplex a "compacting stream"?
  
  enum StreamState: Equatable {
    case ready
    case finished
  }
  
  public  var writableBuffer = MacroCore.shared.emptyBuffer
  public  let maximumSize    : Int
  private var state          = StreamState.ready

  override public var writableFinished : Bool { return state == .finished }
  @inlinable
  override public var writableEnded    : Bool { return writableFinished   }
  @inlinable
  override public var writable         : Bool { return !writableFinished  }

  @inlinable
  open var writableLength : Int { return writableBuffer.count }

  @usableFromInline init(maximumSize: Int) {
    self.maximumSize = maximumSize
  }
  
  @discardableResult
  @inlinable
  public func write(_ bytes: Buffer, whenDone: @escaping () -> Void = {})
              -> Bool
  {
    guard !writableEnded else {
      emit(error: WritableError.writableEnded)
      whenDone()
      return true
    }
    
    let newSize = writableBuffer.count + bytes.count
    guard newSize <= maximumSize else {
      emit(error: ConcatError
            .maximumSizeExceeded(maximumSize: maximumSize,
                                 availableSize: newSize))
      whenDone()
      return true
    }
    
    writableBuffer.append(bytes)
    whenDone()
    return true
  }
  
  public func end() {
    state = .finished
    finishListeners.emit()
    finishListeners.removeAll()
    errorListeners .removeAll()
  }


  // MARK: - CustomStringConvertible

  open var description: String {
    let id = String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    var ms = "<Concat[0x\(id)]:"
    defer { ms += ">" }

    let count = writableBuffer.count
    if writableCorked {
      if count > 0 {
        ms += " corked=#\(count)"
      }
      else {
        ms += " corked(empty)"
      }
    }
    else {
      ms += " buffered=#\(count)"
    }
    
    if writableEnded  { ms += " ended"  }

    return ms
  }
}

/**
 * The ``concat`` middleware failed.
 */
public enum ConcatError: Swift.Error {
  /// The maximum allowed size was exceeded.
  case maximumSizeExceeded(maximumSize: Int, availableSize: Int)
}

/**
 * The default maximum request size for the ``concat`` middleware.
 *
 * Can be set using the `macro.concat.maxsize` environment variable (in bytes),
 * and defaults to 1MB.
 */
public let _defaultConcatMaximumSize =
  process.getenv("macro.concat.maxsize",
                 defaultValue      : 1024 * 1024, // 1MB
                 lowerWarningBound : 128)
