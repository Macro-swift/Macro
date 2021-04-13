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
