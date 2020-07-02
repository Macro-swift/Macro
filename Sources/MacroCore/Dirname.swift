//
//  Dirname.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Foundation.URL
import class  Foundation.FileManager

/**
 * An attempt to emulate the `__dirname` variable in Node modules,
 * requires a function in Swift.
 * `__dirname` gives the directory location of the current Swift file, commonly
 * used to lookup resources that live alongside the Swift source file.
 *
 * Note: Do not confuse w/ `process.cwd()`, which returns the current directory
 *       of the process.
 *
 * Note: Can do synchronous I/O, be careful when to call this!
 *
 * ### Implementation
 *
 * The complicated thing is that SPM does not have proper resource locations.
 * A workaround is to use the `#file` compiler directive, which contains the
 * location of the Swift sourcefile _calling_ `__dirname()`.
 *
 * Now the difficult part is, that the environment may not have access to the
 * source file anymore (because just the library is being deployed).
 * In this case, we return `process.cwd`.
 *
 * ### `swift sh`
 *
 * There are extra issues w/ [swift-sh](https://github.com/mxcl/swift-sh):
 *
 *   https://github.com/mxcl/swift-sh/issues/101
 *
 * So we catch this and (try to) use the CWD in that situation.
 * Note: This does not yet work properly for nested modules!
 */
public func ___dirname(caller: String) -> String {
  // The check for `swift sh`
  let fm = FileManager.default
  
  if caller.contains("swift-sh.cache"), let toolname = process.env["_"] {
    let dirURL  = URL(fileURLWithPath: process.cwd(), isDirectory: true)
    let toolURL = URL(fileURLWithPath: toolname, relativeTo: dirURL)
    
    if fm.fileExists(atPath: toolURL.path) {
      return toolURL.deletingLastPathComponent().path
    }
  }
  
  if fm.fileExists(atPath: caller) {
    return URL(fileURLWithPath: caller).deletingLastPathComponent().path
  }

  return process.cwd()
}

#if swift(>=5.3)
  @inlinable
  public func __dirname(caller: String = #filePath) -> String {
    return ___dirname(caller: caller)
  }
#else
  @inlinable
  public func __dirname(caller: String = #file) -> String {
    return ___dirname(caller: caller)
  }
#endif
