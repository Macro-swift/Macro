//
//  Buffer.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2021 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct NIO.ByteBufferAllocator

/**
 * A lightweight wrapper around the NIO ByteBuffer.
 * 
 * Node Buffer API: https://nodejs.org/api/buffer.html
 *
 * Creating buffers:
 *
 *     Buffer.from("Hello") // UTF-8 data
 *     Buffer()             // empty
 *     Buffer([ 42, 13, 10 ])
 *
 * Reading:
 *
 *     buffer.count
 *     buffer.isEmpty
 *
 *     let slice = buffer.consumeFirst(10)
 *
 * Writing:
 *
 *     buffer.append(otherBuffer)
 *     buffer.append([ 42, 10 ])
 *
 * Converting to strings:
 *
 *     try buffer.toString()
 *     try buffer.toString("hex")
 *     try buffer.toString("base64")
 *     buffer.hexEncodedString()
 *
 */
public struct Buffer: Codable {
  
  public typealias Index = Int
  
  public var byteBuffer : ByteBuffer
    
  @inlinable
  public init(_ byteBuffer: ByteBuffer) {
    self.byteBuffer = byteBuffer
  }
  
  @inlinable
  public init(_ buffer: Buffer) {
    byteBuffer = buffer.byteBuffer
  }

  @inlinable
  public init(capacity  : Int = 1024,
              allocator : ByteBufferAllocator = MacroCore.shared.allocator)
  {
    byteBuffer = allocator.buffer(capacity: capacity)
  }
  
  @inlinable public var isEmpty : Bool { return byteBuffer.readableBytes < 1 }
  @inlinable public var count   : Int  { return byteBuffer.readableBytes }
  
  @inlinable public mutating func append(_ buffer: Buffer) {
    byteBuffer.writeBytes(buffer.byteBuffer.readableBytesView)
  }
  @inlinable public mutating func append(_ buffer: ByteBuffer) {
    byteBuffer.writeBytes(byteBuffer.readableBytesView)
  }
  
  @inlinable
  public mutating func append<S>(contentsOf sequence: S)
                         where S : Sequence, S.Element == UInt8
  {
    byteBuffer.writeBytes(sequence)
  }

  /**
   * Grabs the first `k` bytes from the Buffer and returns it as a new Buffer.
   *
   * If `k` is bigger than the bytes available, this returns all available bytes
   * (and empties the buffer this is called upon).
   */
  @inlinable
  public mutating func consumeFirst(_ k: Int) -> Buffer {
    guard k > 0 else { return MacroCore.shared.emptyBuffer }
    if k >= count {
      let swap = byteBuffer
      byteBuffer = MacroCore.shared.emptyByteBuffer
      return Buffer(swap)
    }
    let readBuffer = byteBuffer.readSlice(length: k)!
    return Buffer(readBuffer)
  }
  
  @inlinable
  subscript(position: Int) -> UInt8 {
    // Note that this is based on the 'readable' index
    set {
      let offset = position >= 0 ? position : (count + position)
      let index  = byteBuffer.readerIndex + offset
      byteBuffer.setInteger(newValue, at: index)
    }
    get {
      let offset = position >= 0 ? position : (count + position)
      let view   = byteBuffer.readableBytesView
      return view[view.index(view.startIndex, offsetBy: offset)]
    }
  }
  
  /**
   * Get a slice of the buffer.
   *
   * - Parameters:
   *   - start: startIndex of the slice, defaults to 0
   *   - end:   endIndex   of the slice, defaults to count
   * - Returns: A Buffer sharing the storage (copy-on-write).
   */
  @inlinable
  func slice(_ start: Int = 0, _ end: Int? = nil) -> Buffer {
    let count       = self.count
    let end         = end ?? count
    let startOffset = start >= 0 ? start : (count + start)
    let endOffset   = end   >= 0 ? end   : (count + end)
    let length      = max(0, endOffset - startOffset)
    let startIndex  = byteBuffer.readerIndex + startOffset
    guard let slice = byteBuffer.getSlice(at: startIndex, length: length) else {
      // We only produce valid ranges?!
      fatalError("Unexpected failure to get slice")
    }
    return Buffer(slice)
  }
  
  
  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    // That's a little weird, but what is spec'ed in Node :-)
    case type, data
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    guard type == "Buffer" else {
      struct InvalidBufferJSON: Swift.Error {}
      throw InvalidBufferJSON()
    }
    let data = try container.decode([ UInt8 ].self, forKey: .data)
    self.init(data)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let data = [ UInt8 ](byteBuffer.readableBytesView)
    try container.encode("Buffer", forKey: .type)
    try container.encode(data,     forKey: .data)
  }
}


public extension Buffer { // MARK: - Searching
  
  @inlinable
  func indexOf(_ value: UInt8) -> Int {
    let view = byteBuffer.readableBytesView
    guard let idx = view.firstIndex(of: value) else { return -1 }
    return idx - view.startIndex
  }
  @inlinable
  func lastIndexOf(_ value: UInt8) -> Int {
    let view = byteBuffer.readableBytesView
    guard let idx = view.lastIndex(of: value) else { return -1 }
    return idx - view.startIndex
  }
  
  @inlinable
  func indexOf<C>(_ string: C, _ byteOffset: Int = 0) -> Int
         where C: Collection, C.Element == UInt8
  {
    let view   = byteBuffer.readableBytesView
    let offset = byteOffset >= 0 ? byteOffset : (count + byteOffset)
    let start  = view.index(view.startIndex, offsetBy: offset)
    guard let idx = view.firstIndex(of: string, startingAt: start) else {
      return -1
    }
    return idx - view.startIndex
  }

  @inlinable
  func indexOf(_ buffer: ByteBuffer, _ byteOffset: Int = 0) -> Int {
    return indexOf(buffer.readableBytesView, byteOffset)
  }
  
  @inlinable
  func indexOf(_ buffer: Buffer, _ byteOffset: Int = 0) -> Int {
    return indexOf(buffer.byteBuffer.readableBytesView, byteOffset)
  }
}

public extension Buffer {
  
  @inlinable
  static func from<S>(_ bytes: S) -> Buffer
                 where S: Collection, S.Element == UInt8
  {
    return Buffer(bytes)
  }
  @inlinable
  init<S>(_ bytes: S) where S: Collection, S.Element == UInt8 {
    self.init(capacity: bytes.count)
    append(contentsOf: bytes)
  }
  
  @inlinable
  static func from<S>(_ bytes: S) -> Buffer
                 where S: Sequence, S.Element == UInt8
  {
    return Buffer(bytes)
  }
  @inlinable
  init<S>(_ bytes: S) where S: Sequence, S.Element == UInt8 {
    self.init()
    append(contentsOf: bytes)
  }
}

extension Buffer: CustomStringConvertible {
  
  @inlinable
  public var description: String {
    if count < 40 {
      return "<Buffer \(hexEncodedString(separator: " "))>"
    }
    else {
      let slice = self.slice(0, 40)
      return "<Buffer: #\(count) \(slice.hexEncodedString(separator: " "))…>"
    }
  }
}
