//
//  ToString.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public extension BinaryInteger {
  
  @inlinable
  func toString(_ radix: Int) -> String {
    return String(self, radix: radix)
  }
  @inlinable
  func toString() -> String { return toString(10) }
}

#if canImport(Foundation)
  import struct Foundation.Date
  import class  Foundation.DateFormatter

  public extension Date {
    
    /* JS/Node Does:
     * new Date().toString()
     * 'Tue Apr 13 2021 16:24:10 GMT+0200 (Central European Summer Time)'
     */
    @usableFromInline
    internal static let jsDateFmt : DateFormatter = {
      let df = DateFormatter()
      // Tue 13 Apr 2021 14:26:59 GMT+0000 (Coordinated Universal Time)
      df.dateFormat = "E d MMM yyyy HH:mm:ss 'GMT'Z '('zzzz')'"
      return df
    }()
    
    @inlinable
    func toString() -> String {
      return Date.jsDateFmt.string(from: self)
    }
  }
#endif // canImport(Foundation)
