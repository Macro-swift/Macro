//
//  Pipe.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * Pipe operator for streams
 *
 * Example:
 *
 *     request | zip | encrypt | fs
 *
 */
@inlinable
@discardableResult
public func |<Input, Output>(left: Input, right: Output) -> Output
             where Input  : ReadableStreamType,
                   Output : WritableStreamType & ErrorEmitterTarget,
                   Input.ReadablePayload == Output.WritablePayload
{
  return left.pipe(right)
}

/**
 * Pipe operator for streams
 *
 * Example:
 *
 *     request | zip | encrypt | fs
 *
 */
@inlinable
@discardableResult
public func |<Input, Output>(left: Input?, right: Output) -> Output
             where Input  : ReadableStreamType,
                   Output : WritableStreamType & ErrorEmitterTarget,
                   Input.ReadablePayload == Output.WritablePayload
{
  guard let left = left else {
    // left side has nothing to pipe, immediately end target stream.
    // TBD: good idea? :-) Added this to support: spawn("ls").stdout | ...
    right.end()
    return right
  }
  return left.pipe(right)
}

/**
 * Pipe operator for streams
 *
 * Example:
 *
 *     [ 'a', 'a', 'a' ] | zip | encrypt | fs
 *
 */
@inlinable
@discardableResult
public func |<Input, Output>(left: Input, right: Output) -> Output
             where Input  : Sequence,
                   Output : WritableStreamType,
                   Input.Iterator.Element == Output.WritablePayload
{
  return left.pipe(right)
}


// MARK: - Stream to Stream pipe

public extension ReadableStreamType {
  
  @inlinable
  func pipe<Output>(_ output       : Output,
                    passEnd        : Bool = true,
                    errorBehaviour : PipeErrorBehaviour = .passOneAndEnd)
       -> Output
       where Output: WritableStreamType & ErrorEmitterTarget,
             Self.ReadablePayload == Output.WritablePayload
  {
    // TODO:
    // This is the naive version. We want the proper, back-pressure supporting,
    // version of Noze.io eventually.
    // TODO: Pipe events. But we can't use `ReadableStreamType` as a type.
    //       Are they really useful for anything anyways?
    
    if passEnd {
      onceEnd {
        if !output.writableEnded { output.end() }
      }
    }
    
    switch errorBehaviour {
      case .dontPassAlong:
        break
      case .passOneAndEnd:
        onceError { error in
          if !output.writableEnded {
            output.emit(error: wrapPipeError(error, for: self))
            output.end()
          }
        }
      case .passAll:
        onError { error in
          if !output.writableEnded {
            output.emit(error: wrapPipeError(error, for: self))
          }
        }
    }
    
    onReadable {
      let payload = self.read()
      output.write(payload, whenDone: {})
    }
    
    return output
  }
}


// MARK: - Pipe Errors

public enum PipeErrorBehaviour {
  
  /// No errors are passed down the pipe. The client code needs to attach a proper onError handler
  /// to the source of the pipe.
  case dontPassAlong
  
  /// When the first error occurs, emit the error on the writable stream, and end that stream.
  case passOneAndEnd
  
  /// Just pass along all errors on the readable to the writable stream.
  case passAll
}

public protocol PipeSourceErrorType: Swift.Error {
  
  var error : Swift.Error { get }
  
  var anyOriginal : Any { get }
  var anyLast     : Any { get }

  func wrapPipeError<Last>(_ error: Swift.Error, for source: Last)
       -> PipeSourceErrorType
       where Last: ReadableStreamType
}

public struct PipeSourceError<Original, Last>: PipeSourceErrorType
                where Original : ReadableStreamType,
                      Last     : ReadableStreamType
{
  
  public let original : Original
  public let last     : Last
  public let error    : Swift.Error

  public func wrapPipeError<NewLast>(_ error: Swift.Error, for source: NewLast)
              -> PipeSourceErrorType
              where NewLast: ReadableStreamType
  {
    return PipeSourceError<Original, NewLast>(original: original, last: source,
                                              error: error)
  }

  public var anyOriginal : Any { return original }
  public var anyLast     : Any { return last     }
}

@usableFromInline
internal func wrapPipeError<Last>(_ error: Swift.Error, for source: Last)
                 -> PipeSourceErrorType
                 where Last: ReadableStreamType
{
  if let pipeError = error as? PipeSourceErrorType {
    return pipeError.wrapPipeError(pipeError.error, for: source)
  }
  return PipeSourceError<Last, Last>(original: source, last: source,
                                     error: error)
}



// MARK: - Sequence Pipe

/**
 * Allows you to pipe any iterator into a WritableStreamType. Note that we
 * assume that a iterator doesn't block.
 */
public extension IteratorProtocol {
  
  // TODO: We could support an async mode for blocking Sequences.
  
  @inlinable
  mutating func pipe<Output>(_ output : Output, callEnd  : Bool = true)
                -> Output
                  where Output: WritableStreamType,
                        Self.Element == Output.WritablePayload
  {
    // TODO:
    // This is the naive version. We want the proper, back-pressure supporting,
    // version of Noze.io eventually.
    
    while let element = next() {
      output.write(element, whenDone: {})
    }
    if callEnd { if !output.writableEnded { output.end() } }
    return output
  }
}

/**
 * Allows you to pipe any sequence into a WritableStreamType. Note that we
 * assume that a SequenceType doesn't block.
 */
public extension Sequence {
  
  @inlinable
  func pipe<Output>(_ output : Output,
                    callEnd  : Bool = true)
       -> Output
       where Output: WritableStreamType,
             Self.Iterator.Element == Output.WritablePayload
  {
    var iterator = makeIterator()
    return iterator.pipe(output, callEnd: callEnd)
  }
}
