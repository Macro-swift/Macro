//
//  fs.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class  NIO.NIOThreadPool
import struct NIO.NonBlockingFileIO
import enum   NIO.System
import class  NIO.NIOFileHandle
import enum   MacroCore.process
import xsys

/**
 * The Macro fs module exports.
 *
 * The aliases in here are used when the user doesn't import the Swift
 * module `fs`, but gets the namespace by importing `Macro`.
 */
public enum FileSystemModule {
  
  /**
   * The worker queue for FS functions.
   */
  public static let threadPool : NIOThreadPool = {
    let tp = NIOThreadPool(numberOfThreads: _defaultIOThreadCount)
    tp.start()
    return tp
  }()

  public static let fileIO = NonBlockingFileIO(threadPool: threadPool)

}

public let _defaultIOThreadCount =
  process.getenv("macro.core.iothreads",
                 defaultValue      : System.coreCount / 2,
                 upperWarningBound : 64)


// MARK: - Directory

public extension FileSystemModule {
  
  @inlinable
  static func readdir(_ path: String,
                      yield: @escaping ( Error?, [ String ]? ) -> Void)
  {
    fs.readdir(path, yield: yield)
  }

  // TBD: should that be a stream? Maybe, but it may not be worth it
  @inlinable
  static func readdirSync(_ path: String) throws -> [ String ] {
    return try fs.readdirSync(path)
  }
}


// MARK: - Streams

public extension FileSystemModule {
  
  @inlinable
  static func createReadStream(_ path: String) -> FileReadStream {
    return fs.createReadStream(path)
  }
  @inlinable
  static func createWriteStream(on eventLoop: EventLoop? = nil,
                                _ path: String,
                                flags: NIOFileHandle.Flags
                                          = .allowFileCreation())
              -> FileWriteStream
  {
    return fs.createWriteStream(on: eventLoop, path, flags: flags)
  }
}


// MARK: - Posix Wrappers

public extension FileSystemModule {
  
  static let F_OK = fs.F_OK
  static let R_OK = fs.R_OK
  static let W_OK = fs.W_OK
  static let X_OK = fs.X_OK


  // MARK: - Async functions, Unix functions are dispatched to a different Q

  /// Check whether we have access to the given path in the given mode.
  @inlinable
  static func access(_ path: String, _ mode: Int = F_OK,
                     yield: @escaping ( Error? ) -> Void) {
    fs.access(path, mode, yield: yield)
  }

  @inlinable
  static func stat(_ path: String,
                   yield: @escaping ( Error?, xsys.stat_struct? ) -> Void)
  {
    fs.stat(path, yield: yield)
  }
  @inlinable
  static func lstat(_ path: String,
                    yield: @escaping ( Error?, xsys.stat_struct? ) -> Void)
  {
    fs.lstat(path, yield: yield)
  }


  // MARK: - Synchronous wrappers

  // If you do a lot of FS operations in sequence, you might want to use a single
  // (async) GCD call, instead of using the convenience async functions.
  //
  // Example:
  //   FileSystemModule.workerQueue.async {
  //     statSync(...)
  //     accessSync(...)
  //     readdirSync(..)
  //     dispatch(MacroCore.module.Q) { cb() } // or EventLoop!
  //   }

  @inlinable static func accessSync(_ path: String, mode: Int = F_OK) throws {
    try fs.accessSync(path, mode: mode)
  }

  @inlinable static func statSync(_ path: String) throws -> xsys.stat_struct {
    return try fs.statSync(path)
  }
  @inlinable static func lstatSync(_ path: String) throws -> xsys.stat_struct {
    return try fs.lstatSync(path)
  }
}


// MARK: - File

import struct   NIO.ByteBuffer
import protocol NIO.EventLoop
import struct   Foundation.Data

public extension FileSystemModule {
  
  @inlinable
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       yield        : @escaping ( Error?, ByteBuffer? ) -> Void)
  {
    fs.readFile(on: eventLoop, path, yield: yield)
  }
  @inlinable
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       _   encoding : String.Encoding,
                       yield        : @escaping ( Error?, String? ) -> Void)
  {
    fs.readFile(on: eventLoop, path, encoding, yield: yield)
  }
  @inlinable
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       _   encoding : String,
                       yield        : @escaping ( Error?, String? ) -> Void)
  {
    fs.readFile(on: eventLoop, path, encoding, yield: yield)
  }

  @inlinable
  static func writeFile(_ path: String, _ data: ByteBuffer,
                        whenDone: @escaping ( Error? ) -> Void)
  {
    fs.writeFile(path, data, whenDone: whenDone)
  }
  @inlinable
  static func writeFile(_ path: String, _ data: Data,
                            whenDone: @escaping ( Error? ) -> Void)
  {
    fs.writeFile(path, data, whenDone: whenDone)
  }
  @inlinable
  static func writeFile(_ path: String, _ string: String,
                        _ encoding: String.Encoding = .utf8,
                        whenDone: @escaping ( Error? ) -> Void)
  {
    fs.writeFile(path, string, encoding, whenDone: whenDone)
  }
  @inlinable
  static func writeFile(_ path: String, _ string: String, _ encoding: String,
                        whenDone: @escaping ( Error? ) -> Void)
  {
    fs.writeFile(path, string, encoding, whenDone: whenDone)
  }

  // MARK: - Synchronous

  @inlinable static func readFileSync(_ path: String) -> ByteBuffer? {
    return fs.readFileSync(path)
  }
  @inlinable
  static func readFileSync(_ path: String, _ encoding: String.Encoding)
              -> String?
  {
    return fs.readFileSync(path, encoding)
  }
  @inlinable
  static func readFileSync(_ path: String, _ encoding: String) -> String? {
    return fs.readFileSync(path, encoding)
  }

  @inlinable
  static func writeFileSync(_ path: String, _ data: ByteBuffer) throws {
    try fs.writeFileSync(path, data)
  }
  @inlinable
  static func writeFileSync(_ path: String, _ data: Data) throws {
    try fs.writeFileSync(path, data)
  }
  @inlinable
  static func writeFileSync(_ path: String, _ string: String,
                            _ encoding: String.Encoding = .utf8) throws
  {
    try fs.writeFileSync(path, string, encoding)
  }
  @inlinable
  static func writeFileSync(_ path: String, _ string: String,
                            _ encoding: String) throws
  {
    try fs.writeFileSync(path, string, encoding)
  }
}


// MARK: - Watch

#if !os(Linux) // 2016-09-12: Not yet available on Linux
import xsys

// MARK: - Watch Files or Directories. Get notified on changes.

public extension FileSystemModule {
  
  @inlinable
  @discardableResult
  static func watch(_ filename : String,
                    persistent : Bool = true,
                    recursive  : Bool = false,
                    listener   : FSWatcherCB? = nil) -> FSWatcherBase
  {
    return fs.watch(filename, persistent: persistent, recursive: recursive,
                    listener: listener)
  }
}

#endif /* !Linux */