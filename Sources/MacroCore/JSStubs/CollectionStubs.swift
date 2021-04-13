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

public extension Collection where Index == Int, Element: Equatable {
  
  @inlinable
  func indexOf(_ element: Element) -> Int {
    return firstIndex(of: element) ?? -1
  }
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

public extension RangeReplaceableCollection {

  @inlinable
  @discardableResult
  mutating func shift() -> Element? {
    guard !isEmpty else { return nil }
    return removeFirst()
  }

  @inlinable
  @discardableResult
  mutating func unshift(_ element: Element) -> Int {
    insert(element, at: startIndex)
    return count
  }
}

public extension RangeReplaceableCollection {
  
  @inlinable
  mutating func concat() -> Self { return self }

  @inlinable
  mutating func concat<S>(_ sequence1: S, sequences: S...) -> Self
                  where S: Sequence, S.Element == Element
  {
    var copy = self
    copy += sequence1
    sequences.forEach { copy += $0 }
    return copy
  }

  @inlinable
  mutating func concat<C>(_ collection1: C, collections: C...) -> Self
                  where C: Collection, C.Element == Element
  {
    let totalCount = self.count + collection1.count
                   + collections.reduce(0, { $0 + $1.count })
    var copy = self
    copy.reserveCapacity(totalCount)
    copy += collection1
    collections.forEach { copy += $0 }
    return copy
  }
}

public extension RangeReplaceableCollection
                   where Self: BidirectionalCollection
{
  
  @inlinable
  mutating func push(_ element: Element) { append(element) }

  @inlinable
  @discardableResult
  mutating func pop() -> Element? {
    guard !isEmpty else { return nil }
    return removeLast()
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
