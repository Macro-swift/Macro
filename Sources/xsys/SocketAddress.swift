//
//  SocketAddress.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 12/04/16.
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

#if !os(WASI)
public protocol SocketAddress {
  
  static var domain: Int32 { get }
  
  init() // create empty address, to be filled by eg getsockname()
  
  var len: __uint8_t { get }
}
#endif // !os(WASI)
