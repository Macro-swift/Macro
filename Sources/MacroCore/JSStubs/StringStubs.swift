//
//  StringStubs.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

@inlinable
public func parseInt(_ string: String, _ radix: Int = 10) -> Int? {
  guard radix >= 2 && radix <= 36 else { return nil }
  let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
  return Int(trimmed, radix: radix)
}

@inlinable
public func parseInt<T>(_ string: T, _ radix: Int = 10) -> Int? {
  return parseInt(String(describing: string), radix)
}

public extension String {
  
  /// Same like `String.split(separator:)`, but returns a `[ String ]` array
  @inlinable
  func split(_ separator: Character) -> [ String ] {
    return split(separator: separator).map { String($0) }
  }
}
