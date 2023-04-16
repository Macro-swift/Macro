//
//  BufferDeprecations.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
import Foundation

public extension Buffer {
  
  @available(*, deprecated, message: "Do not use `encoding` label.")
  @inlinable
  static func from(_ string: String, encoding: String.Encoding)
                throws -> Buffer
  {
    return try from(string, encoding)
  }

  @available(*, deprecated, message: "Do not use `encoding` label.")
  @inlinable
  static func from<S: StringProtocol>(_ string: S,
                                      encoding: String.Encoding)
                throws -> Buffer
  {
    return try from(string, encoding)
  }

  @available(*, deprecated, message: "Do not use `encoding` label.")
  @inlinable
  static func from<S: StringProtocol>(_ string: S, encoding: String) throws
              -> Buffer
  {
    return try from(string, encoding)
  }
}

#endif // canImport(Foundation)
