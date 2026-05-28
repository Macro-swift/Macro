//
//  MkdTemp.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
import WinSDK
#elseif os(Linux) || os(Android)
import Glibc      // EEXIST
import Foundation // POSIXErrorCode
#elseif os(WASI)
import WASILibc   // EEXIST
#else
import Foundation // POSIXErrorCode
#endif

import xsys

/**
 * Creates a unique temporary directory.
 *
 * Appends six random alphanumeric characters to `prefix` and tries to
 * create the resulting directory with mode `0o700`. Retries on collisions
 * up to a small bound. The full path of the created directory is returned.
 *
 * - Parameter prefix: A path prefix, e.g. `"/tmp/myapp-"`. The directory
 *                     name is `prefix` plus six random characters.
 * - Throws: A POSIX error if the directory could not be created.
 */
public func mkdtemp(_ prefix: String,
                    yield: @escaping ( Error?, String? ) -> Void)
{
  FileSystemModule._evalAsync(mkdtempSync, prefix, yield)
}

/**
 * Creates a unique temporary directory.
 *
 * Appends six random alphanumeric characters to `prefix` and tries to
 * create the resulting directory with mode `0o700`. Retries on collisions
 * up to a small bound. The full path of the created directory is returned.
 *
 * - Parameter prefix: A path prefix, e.g. `"/tmp/myapp-"`. The directory
 *                     name is `prefix` plus six random characters.
 * - Throws: A POSIX error if the directory could not be created.
 */
public func mkdtempSync(_ prefix: String) throws -> String {
  let maxRetries = 128
  
  for _ in 1...maxRetries {
    var candidate = prefix
    for _ in 0..<6 { candidate.append(alphabet.randomElement() ?? "-") }
    
    if xsys.mkdir(candidate, 0o700) == 0 { return candidate }
    if xsys.errno != EEXIST {
      throw POSIXErrorCode(rawValue: xsys.errno) ?? .EINVAL
    }
  }
  throw POSIXErrorCode.EEXIST
}
fileprivate let alphabet =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
