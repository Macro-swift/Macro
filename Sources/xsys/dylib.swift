//
//  dylib.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 11/04/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc

  public let dlsym  = Glibc.dlsym
  public let dlopen = Glibc.dlopen
  
#else
  import Darwin
  
  public let dlsym  = Darwin.dlsym
  public let dlopen = Darwin.dlopen
#endif
