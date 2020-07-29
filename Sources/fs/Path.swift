//
//  Path.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/8/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc
#else
  import Darwin
#endif

public enum PathModule {}
public typealias path = PathModule

public extension PathModule {
  
  @inlinable
  static func basename(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let sp = rindex(cs, 47 /* / */)
      guard sp != nil else { return path }
      let bn = sp! + 1
      return String(cString: bn)
    }
  }
  
  @inlinable
  static func dirname(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let sp = UnsafePointer<CChar>(rindex(cs, 47 /* / */))
      guard sp != nil else { return path }
      let len = sp! - cs
      return String.fromCString(cs, length: len)!
    }
  }
}


// MARK: - CString

extension String {
  
  // FIXME: This is probably not necessary anymore?
  @usableFromInline
  static func fromCString(_ cs: UnsafePointer<CChar>, length olength: Int?)
              -> String? 
  {
    guard let length = olength else { // no length given, use \0 std imp
      return String(validatingUTF8: cs)
    }
    
    let buflen = length + 1
    let buf    = UnsafeMutablePointer<CChar>.allocate(capacity: buflen)
    memcpy(buf, cs, length)
    buf[length] = 0 // zero terminate

    let s = String(validatingUTF8: buf)
    buf.deallocate()
    return s
  }
}
