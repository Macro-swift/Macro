//
//  Math.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation) // Just a hack-around to import the system mods
  import Foundation
#endif

public enum Math {}

// Incomplete, a few things are missing.
  
public extension Math {
  static let PI = Double.pi
}

public extension Math {
  
  @inlinable
  static func abs<T>(_ x: T) -> T where T: Comparable & SignedNumeric {
    return Swift.abs(x)
  }

  @inlinable
  static func max<T>(_ x: T, _ y: T) -> T where T: Comparable {
    return Swift.max(x, y)
  }
  @inlinable
  static func min<T>(_ x: T, _ y: T) -> T where T: Comparable {
    return Swift.min(x, y)
  }

  @inlinable
  static func random() -> Double { return Double.random(in: 0...1.0) }
  
  @inlinable
  static func round(_ v: Double) -> Double { return v.rounded() }
  
  @inlinable
  static func sign<T: BinaryInteger>(_ value: T) -> T {
    return value.signum()
  }
  @inlinable
  static func sign(_ value: Double) -> FloatingPointSign {
    return value.sign
  }
}

public extension Math {
  
  @inlinable
  static func max<T>(_ x: T, _ y: T, _ more: T...) -> T where T: Comparable {
    return more.reduce(Math.max(x, y), Math.max)
  }
  @inlinable
  static func min<T>(_ x: T, _ y: T, _ more: T...) -> T where T: Comparable {
    return more.reduce(Math.min(x, y), Math.min)
  }
}

#if canImport(Foundation)

public extension Math {
  
  @inlinable static func acos(_ value: Double) -> Double {
    return Foundation.acos(value)
  }
  @inlinable static func acosh(_ value: Double) -> Double {
    return Foundation.acosh(value)
  }
  @inlinable static func asin(_ value: Double) -> Double {
    return Foundation.asin(value)
  }
  @inlinable static func asinh(_ value: Double) -> Double {
    return Foundation.asinh(value)
  }
  @inlinable static func atan(_ value: Double) -> Double {
    return Foundation.atan(value)
  }
  @inlinable static func atanh(_ value: Double) -> Double {
    return Foundation.atanh(value)
  }
  @inlinable static func atan2(_ x: Double, _ y: Double) -> Double {
    return Foundation.atan2(x, y)
  }
  @inlinable static func ceil(_ value: Double) -> Double {
    return Foundation.ceil(value)
  }
  @inlinable static func cos(_ value: Double) -> Double {
    return Foundation.cos(value)
  }
  @inlinable static func cosh(_ value: Double) -> Double {
    return Foundation.cosh(value)
  }
  @inlinable static func exp(_ value: Double) -> Double {
    return Foundation.exp(value)
  }
  @inlinable static func expm1(_ value: Double) -> Double {
    return Foundation.expm1(value)
  }
  @inlinable static func floor(_ value: Double) -> Double {
    return Foundation.floor(value)
  }
  @inlinable static func hypot(_ x: Double, _ y: Double) -> Double {
    return Foundation.hypot(x, y)
  }
  @inlinable static func log(_ value: Double) -> Double {
    return Foundation.log(value)
  }
  @inlinable static func log1p(_ value: Double) -> Double {
    return Foundation.log1p(value)
  }
  @inlinable static func log10(_ value: Double) -> Double {
    return Foundation.log10(value)
  }
  @inlinable static func log2(_ value: Double) -> Double {
    return Foundation.log2(value)
  }
  @inlinable static func pow(_ x: Double, _ y: Double) -> Double {
    return Foundation.pow(x, y)
  }
  @inlinable static func sin(_ value: Double) -> Double {
    return Foundation.sin(value)
  }
  @inlinable static func sinh(_ value: Double) -> Double {
    return Foundation.sinh(value)
  }
  @inlinable static func sqrt(_ value: Double) -> Double {
    return Foundation.sqrt(value)
  }
  @inlinable static func tan(_ value: Double) -> Double {
    return Foundation.tan(value)
  }
  @inlinable static func tanh(_ value: Double) -> Double {
    return Foundation.tanh(value)
  }
}

public extension Math {
  
  @inlinable
  static func hypot(_ x: Double, _ y: Double, _ more: Double...) -> Double {
    return more.reduce(Math.hypot(x, y), Math.hypot)
  }
}
#endif
