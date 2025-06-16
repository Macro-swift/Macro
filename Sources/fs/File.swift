//
//  File.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.EventLoop
import class    NIO.MultiThreadedEventLoopGroup
import class    NIO.NIOThreadPool
import enum     NIO.ChannelError
import class    MacroCore.MacroCore
import enum     MacroCore.process
import enum     MacroCore.CharsetConversionError
import enum     MacroCore.MacroError
import struct   MacroCore.Buffer
#if canImport(Foundation)
  import struct Foundation.Data
  import struct Foundation.URL
  import class  Foundation.FileManager
#endif
import struct   xsys.mode_t
import let      xsys.mkdir
import let      xsys.rmdir
import var      xsys.errno

// Most, not all, funcs currently require Foundation and should be reimplemented
// using Posix as an alternative.
#if canImport(Foundation)

/**
 * Reads the file specified by the path on the `FileSystemModule`s I/O
 * thread pool and returns the error or `Buffer` on the specified eventloop.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on, if non is specified, a default group is used.
 *   - path:      The path to the file that should be loaded.
 *   - yield:     The closure to call with the resulting Error/`Buffer`.
 */
public func readFile(on eventLoop : EventLoop? = nil,
                     _       path : String,
                     yield        : @escaping ( Error?, Buffer? ) -> Void)
{
  let module = MacroCore.shared.retain()
  let loop   = module.fallbackEventLoop(eventLoop)

  FileSystemModule.threadPool.submit { shouldRun in
    let result : Result<Buffer, Error>
    
    if case shouldRun = NIOThreadPool.WorkItemState.active {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        result = .success(Buffer(data))
      }
      catch {
        result = .failure(error)
      }
    }
    else {
      result = .failure(ChannelError.ioOnClosedChannel)
    }
    
    loop.execute {
      yield(result.jsError, result.jsValue)
      module.release()
    }
  }
}

/**
 * Reads the file specified by the path on the `FileSystemModule`s I/O
 * thread pool and returns the error or `String` on the specified eventloop.
 *
 * If the data could be read, but converted to a `String`, the
 * `CharsetConversionError.failedToConverData` error is returned.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on
 *   - path:      The path to the file that should be loaded.
 *   - encoding:  The `String.Encoding` to use to decode the data.
 *   - yield:     The closure to call with the resulting Error/`String`.
 */
public func readFile(on eventLoop : EventLoop? = nil,
                     _       path : String,
                     _   encoding : String.Encoding,
                     yield        : @escaping ( Error?, String? ) -> Void)
{
  let module = MacroCore.shared.retain()
  let loop   = module.fallbackEventLoop(eventLoop)

  FileSystemModule.threadPool.submit { shouldRun in
    let result : Result<String, Error>

    if case shouldRun = NIOThreadPool.WorkItemState.active {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let s = String(bytes: data, encoding: encoding) else {
          throw CharsetConversionError.failedToConverData(encoding: encoding)
        }
        result = .success(s)
      }
      catch {
        result = .failure(error)
      }
    }
    else {
      result = .failure(ChannelError.ioOnClosedChannel)
    }
    
    loop.execute {
      yield(result.jsError, result.jsValue)
      module.release()
    }
  }
}

/**
 * Reads the file specified by the path on the `FileSystemModule`s I/O
 * thread pool and returns the error or `String` on the specified eventloop.
 *
 * If the data could be read, but converted to a `String`, the
 * `CharsetConversionError.failedToConverData` error is returned.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on.
 *   - path:      The path to the file that should be loaded.
 *   - encoding:  The String encoding to use to decode the file data.
 *   - yield:     The closure to call with the resulting Error/`String`.
 */
@inlinable
public func readFile(on eventLoop : EventLoop? = nil,
                     _       path : String,
                     _   encoding : String,
                     yield        : @escaping ( Error?, String? ) -> Void)
{
  readFile(on: eventLoop, path, String.Encoding.encodingWithName(encoding),
           yield: yield)
}


/**
 * Write a `Buffer` to the given path on the background I/O threadpool.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on.
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - buffer:    The data to write.
 *   - whenDone:  A closure to be called when the file has been written
 *                successfully, or if an error happened.
 */
@inlinable
public func writeFile(on eventLoop: EventLoop? = nil,
                      _ path: String, _ buffer: Buffer,
                      whenDone: @escaping ( Error? ) -> Void)
{
  writeFile(on: eventLoop, path, buffer.data, whenDone: whenDone)
}

/**
 * Write `Data` to the given path on the background I/O threadpool.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on.
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - data:      The data to write.
 *   - whenDone:  A closure to be called when the file has been written
 *                successfully, or if an error happened.
 */
@inlinable
public func writeFile(on eventLoop: EventLoop? = nil,
                      _ path: String, _ data: Data,
                      whenDone: @escaping ( Error? ) -> Void)
{
  let module = MacroCore.shared.retain()
  let loop   = module.fallbackEventLoop(eventLoop)

  FileSystemModule.threadPool.submit { shouldRun in
    let yieldError : Swift.Error?

    if case shouldRun = NIOThreadPool.WorkItemState.active {
      do {
        try writeFileSync(path, data)
        yieldError = nil
      }
      catch {
        yieldError = error
      }
    }
    else {
      yieldError = ChannelError.ioOnClosedChannel
    }
    
    loop.execute {
      whenDone(yieldError)
      module.release()
    }
  }
}

/**
 * Write a `String` to the given path on the background I/O threadpool.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on.
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - string:    The String to write.
 *   - encoding:  The `String.Encoding` to use, defaults to `.utf8`.
 *   - whenDone:  A closure to be called when the file has been written
 *                successfully, or if an error happened.
 */
@inlinable
public func writeFile(_ path: String, _ string: String,
                      _ encoding: String.Encoding = .utf8,
                      whenDone: @escaping ( Error? ) -> Void)
{
  guard let data = string.data(using: encoding) else {
    return whenDone(CharsetConversionError
                      .failedToConverData(encoding: encoding))
  }
  writeFile(path, data, whenDone: whenDone)
}

/**
 * Write a `String` to the given path on the background I/O threadpool.
 *
 * - Parameters:
 *   - eventLoop: If specified, the SwiftNIO `EventLoop` the result should be
 *                delivered on.
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - string:    The String to write.
 *   - encoding:  The String encoding to use.
 *   - whenDone:  A closure to be called when the file has been written
 *                successfully, or if an error happened.
 */
@inlinable
public func writeFile(_ path: String, _ string: String,
                      _ encoding: String,
                      whenDone: @escaping ( Error? ) -> Void)
{
  writeFile(path, string, .encodingWithName(encoding), whenDone: whenDone)
}


// MARK: - Synchronous I/O

/**
 * Reads the file specified by the path synchronously, on the active thread.
 *
 * - Parameters:
 *   - path: The path to the file that should be loaded.
 * - Returns: The `Buffer` loaded, or `nil` if the loading failed.
 */
@inlinable
public func readFileSync(_ path: String) -> Buffer? {
  #if canImport(Foundation)
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      return Buffer(data)
    }
    catch {
      process.emitWarning(error, name: #function)
      return nil
    }
  #else
    fatalError("Port `readFileSync` to non-Foundation systems")
  #endif
}

/**
 * Reads the file specified by the path synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:     The path to the file that should be loaded.
 *   - encoding: The `String.Encoding` to use.
 * - Returns: The `String` loaded, or `nil` if the loading failed.
 */
@inlinable
public func readFileSync(_ path: String, _ encoding: String.Encoding) -> String?
{
  // TODO: support open-flags (r+, a, etc)
  #if canImport(Foundation)
    do {
      let data = try Data(contentsOf: URL(fileURLWithPath: path))
      guard let s = String(bytes: data, encoding: encoding) else {
        process.emitWarning("Could not decode String using \(encoding)",
                            name: #function)
        return nil
      }
      return s
    }
    catch {
      process.emitWarning(error, name: #function)
      return nil
    }
  #else
    fatalError("Port `readFileSync` to non-Foundation systems")
  #endif
}

/**
 * Reads the file specified by the path synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:     The path to the file that should be loaded.
 *   - encoding: The String encoding to use.
 * - Returns: The `String` loaded, or `nil` if the loading failed.
 */
@inlinable
public func readFileSync(_ path: String, _ encoding: String) -> String? {
  return readFileSync(path, String.Encoding.encodingWithName(encoding))
}

/**
 * Write a `Buffer` to the given path synchronously, on the active thread.
 *
 * This does an atomic write.
 *
 * - Parameters:
 *   - path:   The file that should be created/replaced from the `Buffer`.
 *   - buffer: The `Buffer` to write.
 * - Throws: Any lower level file error.
 */
@inlinable
public func writeFileSync(_ path: String, _ buffer: Buffer) throws {
  try writeFileSync(path, buffer.data)
}

#if canImport(Foundation)
/**
 * Write `Data` to the given path synchronously, on the active thread.
 *
 * This does an atomic write.
 *
 * - Parameters:
 *   - path: The file that should be created/replaced from the `Buffer`.
 *   - data: The `Data` to write.
 * - Throws: Any lower level file error.
 */
@inlinable
public func writeFileSync(_ path: String, _ data: Data) throws {
  try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
}
#endif

/**
 * Write a `String` to the given path synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - string:    The String to write.
 *   - encoding:  The String encoding to use.
 * - Throws: Any lower level file error, or
 *           `CharsetConversionError.failedToConverData` if the String could not
 *           be converted.
 */
@inlinable
public func writeFileSync(_ path: String, _ string: String,
                          _ encoding: String.Encoding = .utf8) throws
{
  guard let data = string.data(using: encoding) else {
    throw CharsetConversionError.failedToConverData(encoding: encoding)
  }
  try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
}

/**
 * Write a `String` to the given path synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:      The file that should be created/replaced from the `Buffer`.
 *   - string:    The String to write.
 *   - encoding:  The String encoding to use.
 * - Throws: Any lower level file error, or
 *           `CharsetConversionError.failedToConverData` if the String could not
 *           be converted.
 */
@inlinable
public func writeFileSync(_ path: String, _ string: String,
                          _ encoding: String) throws
{
  try writeFileSync(path, string, .encodingWithName(encoding))
}

#endif // canImport/Foundation



/**
 * The directory creation options that can be used in ``mkdirSync``.
 */
public struct MakeDirOptions: Equatable {
  public var recursive : Bool
  public var mode      : mode_t
  
  @inlinable
  public init(recursive: Bool = false, mode: mode_t = 0o777) {
    self.recursive = recursive
    self.mode      = mode
  }
}

/**
 * Create a directory synchronously, on the active thread.
 *
 * - Parameters:
 *   - path: The path to the directory to create.
 *   - options: The ``MakeDirOptions`` specifying the creation behaviour
 */
public func mkdirSync(_ path: String, _ options: MakeDirOptions = .init())
              throws
{
  #if canImport(Foundation)
    assert(options.mode == 0o777, "unsupported mode")
    let fm = FileManager.default
    try fm.createDirectory(atPath     : path,
                           withIntermediateDirectories: options.recursive,
                           attributes : nil)
  #else
    assert(!options.recursive, "recursive mkdir is unsupported") // TODO
    let rc = xsys.mkdir(path, options.mode)
    if rc != 0 { try throwErrno() }
  #endif
}

/**
 * Create a directory synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:  The path to the directory to create.
 *   - umask: The umask to use, as an octal value. (e.g. "777")
 */
public func mkdirSync(_ path: String, _ umask: String) throws {
  var opts = MakeDirOptions()
  opts.mode = mode_t(umask, radix: 8) ?? 0o777
  try mkdirSync(path, opts)
}

/**
 * Delete a directory synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:  The path to the directory to create.
 */
public func rmdirSync(_ path: String) throws {
  #if canImport(Foundation)
    let fm = FileManager.default
    try fm.removeItem(atPath: path)
  #else
    let rc = xsys.rmdir(path)
    if rc != 0 { try throwErrno() }
  #endif
}

/**
 * Delete a directory or file synchronously, on the active thread.
 *
 * - Parameters:
 *   - path:  The path to the directory to create.
 */
public func unlinkSync(_ path: String) throws {
  #if canImport(Foundation)
    let fm = FileManager.default
    try fm.removeItem(atPath: path)
  #else
    let rc = xsys.unlink(path)
    if rc != 0 { try throwErrno() }
  #endif
}

/**
 * Throw a custom error for the currently active Posix `errno` value.
 */
fileprivate func throwErrno(errno: Int32 = xsys.errno) throws {
  #if true // FIXME: Do this better
    struct PosixError: Swift.Error { let rawValue: Int32 }
    throw PosixError(rawValue: errno)
  #else // cannot construct those?
    throw POSIXError(POSIXErrorCode(rawValue: errno))
  #endif
}
