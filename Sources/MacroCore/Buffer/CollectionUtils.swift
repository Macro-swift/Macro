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
  
  @available(*, unavailable, message: "Not yet implemented")
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
    
    #if false // TODO
    if options.contains(.partialSuffixMatch) {
      fatalError("partial suffixes not yet supported")
    }
    #endif
    
    return nil
  }
  
  @usableFromInline
  func firstIndex<C>(of string: C) -> Index?
         where C: Collection, C.Element == Self.Element
  {
    return firstIndex(of: string, startingAt: startIndex)
  }
}
