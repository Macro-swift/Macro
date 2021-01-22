//
//  CollectionUtils.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public struct StringMatchOptions: OptionSet {
  public let rawValue : UInt8
  
  @inlinable
  public init(rawValue: UInt8) { self.rawValue = rawValue }
  
  /**
   * Continue matching if the Buffer has less content left than the needle
   * we are searching for.
   *
   * For example:
   *
   *     let buf    = try Buffer.from("this is a buf")
   *     let needle = try Buffer.from("buffer")
   *     XCTAssertEqual(-1, buf.indexOf(needle))
   *     XCTAssertEqual(10, buf.indexOf(needle, options: .partialSuffixMatch))
   *
   * Without the option, `indexOf` will stop searching after the "is", because
   * the buffer can't possibly contain the needle anymore.
   * 
   * With the option is set, `indexOf` will continue searching for the longest
   * possible prefix of the needle. In the example that is `buf`.
   */
  public static let partialSuffixMatch = StringMatchOptions(rawValue: 1 << 0)
}

extension Collection where Element : Equatable {
  
  @usableFromInline
  func firstIndex<C>(of string: C, startingAt index: Index,
                     options: StringMatchOptions = [])
         -> Index?
         where C: Collection, C.Element == Self.Element
  {
    var cursor    = index
    var remaining = distance(from: cursor, to: endIndex)
    let matchLen  = string.count
    
    guard remaining >= matchLen else { return nil   }
    guard matchLen > 0          else { return index }
    
    // TBD: Is this too naive? There is probably some better algorithm for this.
    // TBD: Rather use `memmem`?
    let c0 = string.first
    while remaining >= matchLen {
      if self[cursor] == c0 { // first element matches
        let cursorLast = self.index(cursor, offsetBy: matchLen)
        let view       = self[cursor..<cursorLast]
        if view.elementsEqual(string) { return cursor }
      }
      
      remaining -= 1
      cursor = self.index(after: cursor)
    }
    
    if options.contains(.partialSuffixMatch) {
      while remaining > 0 {
        if self[cursor] == c0 { // first element matches
          let view       = self[cursor...]
          let partialEnd = string.index(string.startIndex, offsetBy: remaining)
          let partial    = string[..<partialEnd]
          if view.elementsEqual(partial) { return cursor }
        }
        
        remaining -= 1
        cursor = self.index(after: cursor)
      }
    }
    
    return nil
  }
  
  @usableFromInline
  func firstIndex<C>(of string: C, options: StringMatchOptions = []) -> Index?
         where C: Collection, C.Element == Self.Element
  {
    return firstIndex(of: string, startingAt: startIndex, options: options)
  }
}
