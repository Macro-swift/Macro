//
//  fs.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2021 ZeeZide GmbH. All rights reserved.
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
   * The worker queue for asynchronous file system functions.
   *
   * The number of threads is set using the `macro.core.iothreads` environment
   * variable and defaults to half the number of machine cores (e.g. a machine
   * w/ 8 CPU cores will be assigned 4 I/O threads).
   */
  public static let threadPool : NIOThreadPool = {
    let tp = NIOThreadPool(numberOfThreads: _defaultIOThreadCount)
    tp.start()
    return tp
  }()

  /**
   * A NIO `NonBlockingFileIO` object for the `fs.threadPool`.
   */
  public static let fileIO = NonBlockingFileIO(threadPool: threadPool)

}

/**
 * The number of I/O threads is set using the `macro.core.iothreads` environment
 * variable and defaults to half the number of machine cores (e.g. a machine
 * w/ 8 CPU cores will be assigned 4 I/O threads).
 */
public let _defaultIOThreadCount =
  process.getenv("macro.core.iothreads",
                 defaultValue      : max(1, System.coreCount / 2),
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

import protocol NIO.EventLoop
import struct   Foundation.Data
import struct   MacroCore.Buffer

public extension FileSystemModule {
  
  @inlinable
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       yield        : @escaping ( Error?, Buffer? ) -> Void)
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
  static func writeFile(_ path: String, _ data: Buffer,
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

  @inlinable static func readFileSync(_ path: String) -> Buffer? {
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
  static func writeFileSync(_ path: String, _ data: Buffer) throws {
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

  @inlinable
  static func mkdirSync(_ path: String, _ options: MakeDirOptions = .init())
                throws
  {
    try fs.mkdirSync(path, options)
  }
  @inlinable
  func mkdirSync(_ path: String, _ umask: String) throws {
    // TODO: this should probably support rwx+ like strings?
    try fs.mkdirSync(path, umask)
  }

  @inlinable
  static func rmdirSync(_ path: String) throws {
    try fs.rmdirSync(path)
  }
  @inlinable
  static func unlinkSync(_ path: String) throws {
    try fs.unlinkSync(path)
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


// MARK: - Exists

public extension FileSystemModule {
  
  /**
   * Check whether the path exists.
   *
   * Use `fs.access()` instead.
   */
  @available(*, deprecated, message: "Using `access` is recommended.")
  @inlinable
  static func exists(_ path: String, yield: @escaping ( Bool ) -> Void) {
    fs.access(path) { error in
      yield(error == nil)
    }    
  }

  /**
   * Check whether the given path exists.
   *
   * As in Node: `exists` is deprecated, but `existsSync` is not :-)
   */
  @inlinable
  static func existsSync(_ path: String) -> Bool {
    do {
      try fs.accessSync(path)
      return true
    }
    catch {
      return false
    }
  }
}
