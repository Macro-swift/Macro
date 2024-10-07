//
//  DetectXcode.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import func WinSDK.strstr
#elseif os(Linux)
  import func Glibc.strstr
#else
  import func Darwin.strstr
#endif
import let xsys.getenv

public extension process {

  #if os(Linux) || os(Windows)
    static let isRunningInXCode = false
  #else
    static let isRunningInXCode : Bool = {
      // TBD: is there a better way?
      if let s = xsys.getenv("XPC_SERVICE_NAME") { // not in Xcode 16 anymore
        if strstr(s, "Xcode") != nil { return true }
      }
      if xsys.getenv("__XCODE_BUILT_PRODUCTS_DIR_PATHS") != nil { // Xcode 16
        return true
      }
      return false
    }()
  #endif
}
