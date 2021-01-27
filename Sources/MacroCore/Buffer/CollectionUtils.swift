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
    
    guard remaining >= matchLen || options.contains(.partialSuffixMatch) else {
      return nil
    }
    guard matchLen > 0 else { return index }
    let c0 = string.first!

    // TBD: Is this too naive? There is probably some better algorithm for this.
    // TBD: Rather use `memmem`?
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
          let partialEnd = string.index(string.startIndex,
                                        offsetBy: Swift.min(remaining,
                                                            matchLen))
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


// MARK: - The optimized ByteBuffer version

import struct NIO.ByteBufferView
extension ByteBufferView {
  
  @usableFromInline
  func firstIndex(of string: [ UInt8 ], startingAt startIndex: Index,
                  options: StringMatchOptions = [])
         -> Index?
  {
    // Yes, a little cleanup wouldn't hurt here :-)
    var cursor    = startIndex
    var remaining = distance(from: cursor, to: endIndex)
    let matchLen  = string.count
    
    guard remaining >= matchLen || options.contains(.partialSuffixMatch) else {
      return nil
    }
    guard matchLen > 0 else { return startIndex }
    
    
    // MARK: - Search for the first byte
    
    let c0 = string[0]
    do {
      let distanceFromCursor = find(c0, in: self[cursor...])
      guard distanceFromCursor >= 0 else { return nil }
      cursor    += distanceFromCursor
      remaining -= distanceFromCursor
    }
    assert(self[cursor] == c0)

    // MARK: - Search for the complete string if there is enough space
    
    if matchLen <= remaining {
      let distanceFromCursor = find(string, in: self[cursor...])
      if distanceFromCursor >= 0 { // found complete string
        return cursor + distanceFromCursor
      }
    }
    assert(self[cursor] == c0) // shouldn't have changed

    // MARK: - Partial Suffix Match
    
    if options.contains(.partialSuffixMatch) {
      // We are just looking for suffixes
      if remaining > matchLen {
        let diff = remaining - matchLen
        remaining = matchLen
        cursor   += diff
        
        let distanceFromCursor = find(c0, in: self[cursor...])
        guard distanceFromCursor >= 0 else { return nil }
        cursor    += distanceFromCursor
        remaining -= distanceFromCursor
      }
      
      while remaining > 0 {
        assert(self[cursor] == c0)
        if self[cursor] == c0 { // first element matches
          // Slow search again
          let view       = self[cursor...]
          let partialEnd = string.index(string.startIndex,
                                        offsetBy: Swift.min(remaining,
                                                            matchLen))
          let partial    = string[..<partialEnd]
          if view.elementsEqual(partial) { return cursor }
        }

        let distanceFromCursor = find(c0, in: self[cursor...])
        guard distanceFromCursor >= 0 else { return nil }
        cursor    += distanceFromCursor
        remaining -= distanceFromCursor
      }
    }
    
    return nil
  }

  @usableFromInline
  func firstIndex(of string: [ UInt8 ], options: StringMatchOptions = [])
       -> Index?
  {
    return firstIndex(of: string, startingAt: startIndex, options: options)
  }
}


// MARK: - memchr/memmem

#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#elseif canImport(WASIClib)
  import WASIClib
#endif


fileprivate func find(_ byte: UInt8, in bb: ByteBufferView) -> Int {
  // Perf: firstIndex(of:) is !2x slower than memchr (well, in Debug)
  assert(bb.count > 0)
  return bb.withUnsafeBytes { rbp in
    guard let rb = rbp.baseAddress else { return -1 }
    let idx = memchr(rb, Int32(byte), rbp.count)
    guard let ptr = idx else { return -1 }
    let a : UnsafeRawPointer = rbp.baseAddress!
    let b = UnsafeRawPointer(ptr)
    assert(a <= b)
    return b - a
  }
}

fileprivate func find(_ string: [ UInt8 ], in bb: ByteBufferView) -> Int {
  assert(!string.isEmpty) // could work, but not used like that in here
  guard !string.isEmpty else { return 0 } // TBD
  assert(string.count <= bb.count)
  return bb.withUnsafeBytes { rbp in
    return string.withUnsafeBytes { needleRBP in
      guard let rb = rbp.baseAddress, let nb = needleRBP.baseAddress else {
        return -1
      }
      #if true // && os(Linux) // Swift Glibc doesn't have/export memmem :-/
        // Note: Sticking to a single version for all platforms.
        let byte      = needleRBP[0]
        let matchLen  = needleRBP.count
        var remaining = rbp.count
        var cursor    = rb
      
        while remaining >= matchLen {
          guard let b = UnsafeRawPointer(memchr(cursor, Int32(byte), remaining))
          else {
            return -1
          }
          assert(cursor <= b)
          remaining -= (b - cursor)
          cursor     = b
          
          if memcmp(cursor, nb, matchLen) == 0 {
            assert(rb <= b)
            return b - rb
          }
          
          remaining -= 1
          cursor    += 1
        }
        return -1
      #else
        let idx = memmem(rb, rbp.count, nb, needleRBP.count)
        guard let ptr = idx else { return -1 }
        let a : UnsafeRawPointer = rb
        let b = UnsafeRawPointer(ptr)
        assert(a <= b)
        return b - a
      #endif
    }
  }
}
