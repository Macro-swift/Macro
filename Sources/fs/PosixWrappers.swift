//
//  PosixWrappers.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/8/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import xsys
#if os(Linux)
#else
  import Foundation // for POSIXError
#endif

public let F_OK = Int(xsys.F_OK)
public let R_OK = Int(xsys.R_OK)
public let W_OK = Int(xsys.W_OK)
public let X_OK = Int(xsys.X_OK)


// MARK: - Async functions, Unix functions are dispatched to a different Q

/// Check whether we have access to the given path in the given mode.
@inlinable
public func access(_ path: String, _ mode: Int = F_OK,
                   yield: @escaping ( Error? ) -> Void) {
  FileSystemModule._evalAsync(accessSync, (path, mode), yield)
}

@inlinable
public func stat(_ path: String,
                 yield: @escaping ( Error?, xsys.stat_struct? ) -> Void)
{
  FileSystemModule._evalAsync(statSync, path, yield)
}
@inlinable
public func lstat(_ path: String,
                  yield: @escaping ( Error?, xsys.stat_struct? ) -> Void)
{
  FileSystemModule._evalAsync(lstatSync, path, yield)
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

@inlinable
public func accessSync(_ path: String, mode: Int = F_OK) throws {
  let rc = xsys.access(path, Int32(mode))
  if rc != 0 { throw POSIXErrorCode(rawValue: xsys.errno)! }
}

@inlinable
public func statSync(_ path: String) throws -> xsys.stat_struct {
  var info = xsys.stat_struct()
  let rc   = xsys.stat(path, &info)
  if rc != 0 { throw POSIXErrorCode(rawValue: xsys.errno)! }
  return info
}
@inlinable
public func lstatSync(_ path: String) throws -> xsys.stat_struct {
  var info = xsys.stat_struct()
  let rc   = xsys.lstat(path, &info)
  if rc != 0 { throw POSIXErrorCode(rawValue: xsys.errno)! }
  return info
}
