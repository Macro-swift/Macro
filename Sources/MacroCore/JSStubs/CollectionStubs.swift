//
//  CollectionStubs.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public extension Array {
  
  @inlinable
  mutating func push(_ element: Element) { append(element) }

  @inlinable
  @discardableResult
  mutating func pop() -> Element? {
    guard !isEmpty else { return nil }
    return removeLast()
  }

  @inlinable
  @discardableResult
  mutating func shift() -> Element? {
    guard !isEmpty else { return nil }
    return removeFirst()
  }

  @inlinable
  @discardableResult
  mutating func unshift(_ element: Element) -> Int {
    insert(element, at: 0)
    return count
  }
}

public extension Array where Element: Equatable {
  
  @inlinable
  func indexOf(_ element: Element) -> Int {
    return firstIndex(of: element) ?? -1
  }
}

public extension Sequence where Element: StringProtocol {
  
  @inlinable
  func join(_ separator: String = ",") -> String {
    return joined(separator: separator)
  }
}

public extension Sequence {
  
  /**
   * Treat optionals as booleans when filtering.
   *
   * Example:
   *
   *     return Object.keys(index.toc())
   *       .filter { $0.match("^" + searchPath.replace("\\" /*/g?!*/, "\\\\")) }
   */
  @inlinable
  func filter<Value>(_ isIncluded: ( Element ) throws -> Value?)
         rethrows -> [ Element ]
  {
    return try filter {
      switch try isIncluded($0) {
        case .some: return true
        case .none: return false
      }
    }
  }
}
