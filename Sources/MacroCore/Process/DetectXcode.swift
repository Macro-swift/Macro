//
//  DetectXcode.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if os(Linux)
  import func Glibc.strstr
#else
  import func Darwin.strstr
#endif
import let xsys.getenv

public extension process {

  #if os(Linux)
    static let isRunningInXCode = false
  #else
    static let isRunningInXCode : Bool = {
      // TBD: is there a better way?
      guard let s = xsys.getenv("XPC_SERVICE_NAME") else { return false }
      return strstr(s, "Xcode") != nil
    }()
  #endif
}
