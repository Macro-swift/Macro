//
//  dylib.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 11/04/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(WASI)
  import WASILibc
  // No dynamic library support on WASI
#elseif os(Linux) || os(Android)
  import Glibc

  public let dlsym  = Glibc.dlsym
  public let dlopen = Glibc.dlopen
  
#else
  import Darwin
  
  public let dlsym  = Darwin.dlsym
  public let dlopen = Darwin.dlopen
#endif
