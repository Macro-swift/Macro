//
//  Module.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 11/04/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(WASI)
  import WASILibc
#elseif os(Linux) || os(Android)
  import Glibc
#else
  import Darwin
#endif

public struct XSysModule {
}
public let module = XSysModule()
