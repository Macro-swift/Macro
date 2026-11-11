//
//  BufferHexEncoding.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2024 ZeeZide GmbH. All rights reserved.
//

import NIOCore

@usableFromInline
internal let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }
@usableFromInline
internal let upperHexAlphabet = "0123456789ABCDEF".unicodeScalars.map { $0 }

public extension Buffer {

  /**
   * Returns the data in the buffer as a hex encoded string.
   *
   * Example:
   * ```swift
   * let buffer = Buffer("Hello".utf8)
   * let string = buffer.hexEncodedString()
   * // "48656c6c6f"
   * ```
   *
   * Each byte is represented by two hex digits, e.g. `6c` in the example.
   *
   * `hex` is also recognized as a string encoding, this works as well:
   * ```swift
   * let buffer = Buffer("Hello".utf8)
   * let string = try buffer.toString("hex")
   * // "48656c6c6f"
   * ```
   *
   * - Parameters:
   *   - uppercase: If true, the a-f hexdigits are generated in
   *                uppercase (ABCDEF). Defaults to false.
   *   - separator: A string to insert between the individual bytes, e.g. " "
   *                or ":"
   * - Returns:  The Buffer encoded as a hex string.
   */
  @inlinable
  func hexEncodedString(uppercase: Bool = false, separator: String? = nil)
       -> String
  {
      // https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex
    return String(byteBuffer.readableBytesView.reduce(into: "".unicodeScalars, {
      ( result, value ) in
      if uppercase {
        if let separator = separator, !result.isEmpty {
          result.append(contentsOf: separator.unicodeScalars)
        }
        result.append(upperHexAlphabet[Int(value / 16)])
        result.append(upperHexAlphabet[Int(value % 16)])
      }
      else {
        if let separator = separator, !result.isEmpty {
          result.append(contentsOf: separator.unicodeScalars)
        }
        result.append(hexAlphabet[Int(value / 16)])
        result.append(hexAlphabet[Int(value % 16)])
      }
    }))
  }
  
  /**
   * Appends the bytes represented by a hex encoded string to the Buffer.
   *
   * Example:
   * ```swift
   * let buffer = Buffer()
   * buffer.writeHex("48656c6c6f")
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   * `hex` is also recognized as a string encoding, this works as well:
   * ```swift
   * let buffer = try Buffer.from("48656c6c6f", "hex")
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   * - Parameters:
   *   - hex: A hex encoded string, no spaces etc allowed between the bytes.
   * - Returns: true if successful, false if the input is invalid
   */
  @inlinable
  @discardableResult
  mutating func writeHex<S: StringProtocol>(_ hex: S) -> Bool {
    return writeHex(hex.utf8)
  }
}

extension Buffer {

  /**
   * Appends the bytes represented by a hex encoded ASCII bytes to the Buffer.
   *
   * If the input is invalid, the Buffer is left unchanged.
   *
   * - Parameters:
   *   - hex: The bytes of a hex encoded text, no spaces etc allowed between
   *          the bytes.
   * - Returns: true if successful, false if the input is invalid
   */
  @usableFromInline
  @discardableResult
  mutating func writeHex<S>(_ hex: S) -> Bool
    where S: Sequence, S.Element == UInt8
  {
    @inline(__always) func decodeNibble(_ c: UInt8) -> UInt8? {
      switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
          return c - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
          return c - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
          return c - UInt8(ascii: "a") + 10
        default          : return nil
      }
    }

    let start = byteBuffer.writerIndex
    var even  = true
    var byte  : UInt8 = 0
    for c in hex {
      guard let value = decodeNibble(c) else {
        byteBuffer.moveWriterIndex(to: start)
        return false
      }
      
      if even { byte = value << 4 }
      else    { byteBuffer.writeInteger(byte | value) }
      even = !even
    }
    if !even { byteBuffer.moveWriterIndex(to: start) }
    return even
  }
}
