//
//  File.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2021 ZeeZide GmbH. All rights reserved.
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
@inlinable
public func readFile(on eventLoop : EventLoop? = nil,
                     _       path : String,
                     _   encoding : String,
                     yield        : @escaping ( Error?, String? ) -> Void)
{
  readFile(on: eventLoop, path, String.Encoding.encodingWithName(encoding),
           yield: yield)
}

@inlinable
public func writeFile(_ path: String, _ buffer: Buffer,
                      whenDone: @escaping ( Error? ) -> Void)
{
  writeFile(path, buffer.data, whenDone: whenDone)
}
#if canImport(Foundation)
@inlinable
public func writeFile(on eventLoop : EventLoop? = nil,
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
#endif
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
@inlinable
public func writeFile(_ path: String, _ string: String,
                      _ encoding: String,
                      whenDone: @escaping ( Error? ) -> Void)
{
  writeFile(path, string, .encodingWithName(encoding), whenDone: whenDone)
}


// MARK: - Synchronous

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

@inlinable
public func readFileSync(_ path: String, _ encoding: String.Encoding) -> String?
{
  #if canImport(Foundation)
  // TODO: support open-flags (r+, a, etc)
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
@inlinable
public func readFileSync(_ path: String, _ encoding: String) -> String? {
  return readFileSync(path, String.Encoding.encodingWithName(encoding))
}

@inlinable
public func writeFileSync(_ path: String, _ buffer: Buffer) throws {
  try writeFileSync(path, buffer.data)
}
#if canImport(Foundation)
@inlinable
public func writeFileSync(_ path: String, _ data: Data) throws {
  try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
}
#endif
@inlinable
public func writeFileSync(_ path: String, _ string: String,
                          _ encoding: String.Encoding = .utf8) throws
{
  guard let data = string.data(using: encoding) else {
    throw CharsetConversionError.failedToConverData(encoding: encoding)
  }
  try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
}
@inlinable
public func writeFileSync(_ path: String, _ string: String,
                          _ encoding: String) throws
{
  try writeFileSync(path, string, .encodingWithName(encoding))
}

public struct MakeDirOptions: Equatable {
  public var recursive = false
  public var mode      : mode_t = 0777
  
  @inlinable
  public init(recursive: Bool = false, mode: mode_t = 0o777) {
    self.recursive = recursive
    self.mode      = mode
  }
}

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
public func mkdirSync(_ path: String, _ umask: String) throws {
  var opts = MakeDirOptions()
  opts.mode = mode_t(umask, radix: 8) ?? 0o777
  try mkdirSync(path, opts)
}

public func rmdirSync(_ path: String) throws {
  #if canImport(Foundation)
    let fm = FileManager.default
    try fm.removeItem(atPath: path)
  #else
    let rc = xsys.rmdir(path)
    if rc != 0 { try throwErrno() }
  #endif
}

public func unlinkSync(_ path: String) throws {
  #if canImport(Foundation)
    let fm = FileManager.default
    try fm.removeItem(atPath: path)
  #else
    let rc = xsys.unlink(path)
    if rc != 0 { try throwErrno() }
  #endif
}

fileprivate func throwErrno() throws {
  #if true // FIXME: Do this better
    struct PosixError: Swift.Error { let rawValue: Int32 }
    throw PosixError(rawValue: xsys.errno)
  #else // cannot construct those?
    throw POSIXError(POSIXErrorCode(rawValue: errno))
  #endif
}
