//
//  Buffer.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import Foundation
import NIOFoundationCompat
import struct NIO.ByteBuffer
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
public struct Buffer {
  
  public var byteBuffer : ByteBuffer
  
  @inlinable public init(_ byteBuffer: ByteBuffer) {
    self.byteBuffer = byteBuffer
  }
  
  @inlinable public init(_ buffer: Buffer) {
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
  @inlinable public mutating func consumeFirst(_ k: Int) -> Buffer {
    guard k > 0 else { return MacroCore.shared.emptyBuffer }
    if k >= count {
      let swap = byteBuffer
      byteBuffer = MacroCore.shared.emptyByteBuffer
      return Buffer(swap)
    }
    let readBuffer = byteBuffer.readSlice(length: k)!
    return Buffer(readBuffer)
  }
}

public extension Buffer {
  
  @inlinable init<S>(_ bytes: S) where S: Collection, S.Element == UInt8 {
    self.init(capacity: bytes.count)
    append(contentsOf: bytes)
  }
  
  @inlinable init<S>(_ bytes: S) where S: Sequence, S.Element == UInt8 {
    self.init()
    append(contentsOf: bytes)
  }
  
  /**
   * Initialize the Buffer with the contents of the given `Data`. Copies the
   * bytes.
   */
  @inlinable init(_ data: Data) {
    self.init(capacity: data.count)
    byteBuffer.writeBytes(data)
  }
  
  /**
   * Initialize the Buffer with the UTF-8 data in the String.
   */
  @inlinable init(_ string: String) {
    self.init(string.utf8)
  }
  
  /**
   * Initialize the Buffer with the UTF-8 data in the String.
   */
  @inlinable init<S: StringProtocol>(_ string: S) {
    self.init(string.utf8)
  }

  @inlinable var data : Data {
    return byteBuffer.getData(at     : byteBuffer.readerIndex,
                              length : byteBuffer.readableBytes) ?? Data()
  }
}

public extension Buffer {
  
  /**
   * Creates a Buffer from the given string, in the given encoding (defaults to
   * UTF-8).
   * If the string cannot be represented in the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameters:
   *   - string:   The string to convert to a Buffer.
   *   - encoding: The requested encoding, defaults to `.utf8`.
   * - Returns: A Buffer representing the string in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  static func from(_ string: String, encoding: String.Encoding = .utf8)
                throws -> Buffer
  {
    guard let data = string.data(using: encoding) else {
      throw CharsetConversionError.failedToConverData(encoding: encoding)
    }
    return Buffer(data)
  }

  /**
   * Creates a Buffer from the given string, in the given encoding (defaults to
   * UTF-8).
   * If the string cannot be represented in the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameters:
   *   - string:   The string to convert to a Buffer.
   *   - encoding: The requested encoding, defaults to `.utf8`.
   * - Returns: A Buffer representing the string in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  static func from<S: StringProtocol>(_ string: S,
                                      encoding: String.Encoding = .utf8)
                throws -> Buffer
  {
    guard let data = string.data(using: encoding) else {
      throw CharsetConversionError.failedToConverData(encoding: encoding)
    }
    return Buffer(data)
  }

  /**
   * Creates a Buffer from the given string, in the given encoding (e.g.
   * "hex" or "utf-8").
   * If the string cannot be represented in the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameters:
   *   - string:   The string to convert to a Buffer.
   *   - encoding: The requested encoding, e.g. 'utf8' or 'hex'.
   * - Returns: A Buffer representing the string in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  static func from<S: StringProtocol>(_ string: S, encoding: String) throws
              -> Buffer
  {
    switch encoding {
      case "hex":
        var buffer = Buffer(capacity: string.utf16.count / 2)
        guard buffer.writeHexString(string) else {
          throw DataDecodingError.failedToDecodeHexString
        }
        return buffer
      
      case "base64":
        guard let data = Data(base64Encoded: String(string)) else {
          throw DataDecodingError.failedToDecodeBase64
        }
        return Buffer(data)

      default:
        return try from(string, encoding: .encodingWithName(encoding))
    }
  }

  /**
   * Returns true if the string argument represents a valid encoding, i.e.
   * if it can be used in the `Buffer.toString` method.
   *
   * Example:
   *
   *     Buffer.isEncoding("utf8")        // true
   *     Buffer.isEncoding("hex")         // true
   *     Buffer.isEncoding("base64")      // true
   *     Buffer.isEncoding("alwaysright") // false
   *
   * - Parameter encoding: The name of an encoding, e.g. 'utf8' or 'hex'
   * - Returns: true if the name is a known encoding, false otherwise.
   */
  @inlinable
  static func isEncoding(_ encoding: String) -> Bool {
    switch encoding {
      case "hex", "base64": return true
      default: return String.Encoding.isEncoding(encoding)
    }
  }
  
  /**
   * If the Buffer contains a valid string in the given encoding (defaults to
   * UTF-8), this method returns that data as a String.
   * If the data is invalid for the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameter encoding: The requested encoding, defaults to `.utf8`
   * - Returns: A string representing the Buffer in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  func toString(_ encoding: String.Encoding = .utf8) throws -> String {
    guard let string = String(data: data, encoding: encoding) else {
      throw CharsetConversionError.failedToConvertString(encoding: encoding)
    }
    return string
  }
  
  /**
   * If the Buffer contains a valid string in the encoding with the given
   * name (e.g. "hex" or "utf-8"), this method returns that data as a String.
   * If the data is invalid for the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameter encoding: The requested encoding, e.g. 'hex' or 'base64'
   * - Returns: A string representing the Buffer in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  func toString(_ encoding: String) throws -> String {
    switch encoding {
      case "hex"    : return hexEncodedString()
      case "base64" : return data.base64EncodedString()
      default: return try toString(.encodingWithName(encoding))
    }
  }
}

extension Buffer: CustomStringConvertible {
  
  @inlinable
  public var description: String {
    return "<Buffer: #\(byteBuffer.readableBytes)>"
  }
}

public enum DataDecodingError: Swift.Error {
  case failedToDecodeHexString
  case failedToDecodeBase64
}
public enum DataEncodingError: Swift.Error {
  case failedToReadData
}

@usableFromInline
internal let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }
@usableFromInline
internal let upperHexAlphabet = "0123456789ABCDEF".unicodeScalars.map { $0 }

extension Buffer {

  /**
   * Returns the data in the buffer as a hex encoded string.
   *
   * Example:
   *
   *   let buffer = Buffer("Hello!".utf8)
   *   let string = buffer.hexEncodedString()
   *   "48656c6c6f0a"
   * 
   * Each byte is represented by two hex digits, e.g. `2d` in the example.
   *
   * - Parameter uppercase: If true, the a-f hexdigits are generated in
   *                        uppercase (ABCDEF). Defaults to false.
   */
  @inlinable
  public func hexEncodedString(uppercase: Bool = false) -> String {
      // https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex
    return String(byteBuffer.readableBytesView.reduce(into: "".unicodeScalars, {
      ( result, value ) in
      if uppercase {
        result.append(upperHexAlphabet[Int(value / 16)])
        result.append(upperHexAlphabet[Int(value % 16)])
      }
      else {
        result.append(hexAlphabet[Int(value / 16)])
        result.append(hexAlphabet[Int(value % 16)])
      }
    }))
  }
  
  /**
   * Appends a hex encoded string to the Buffer.
   *
   * Example:
   *
   *   let buffer = Buffer()
   *   buffer.writeHexString("48656c6c6f0a")
   *   buffer.re
   *   let buffer = Buffer("Hello!".utf8)
   *   let string = buffer.hexEncodedString()
   *   "48656c6c6f0a"
   */
  @inlinable
  mutating func writeHexString<S: StringProtocol>(_ hexString: S) -> Bool {
    // https://stackoverflow.com/questions/41485494/convert-hex-encoded-string
    func decodeNibble(u: UInt16) -> UInt8? {
      switch(u) {
        case 0x30 ... 0x39: return UInt8(u - 0x30)
        case 0x41 ... 0x46: return UInt8(u - 0x41 + 10)
        case 0x61 ... 0x66: return UInt8(u - 0x61 + 10)
        default:            return nil
      }
    }

    var even = true
    var byte : UInt8 = 0
    for c in hexString.utf16 {
      guard let val = decodeNibble(u: c) else { return false }
      if even {
        byte = val << 4
      }
      else {
        byte += val
        byteBuffer.writeInteger(byte)
      }
      even = !even
    }
    return even
  }
}
