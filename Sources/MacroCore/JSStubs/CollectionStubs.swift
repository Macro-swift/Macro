//
//  CollectionStubs.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public extension Collection {
  
  @inlinable
  var length: Int { return count }
}

public extension RandomAccessCollection where Index == Int {
  
  @inlinable
  func slice(_ start: Int = 0, _ end: Int? = nil) -> [ Element ] {
    guard isEmpty else { return [] }
    var start = start >= 0 ? start : count + start
    var end   = end.flatMap { end in end >= 0 ? end : count + end } ?? count
    if start < 0 { start = 0 }
    else if start >= count { start = count - 1 }
    if end < 0 { end = 0 }
    else if end >= count { end = count - 1 }
    if start == end  { return [] }
    if end < start { swap(&start, &end) }
    return Array(self[start..<end])
  }
}

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
