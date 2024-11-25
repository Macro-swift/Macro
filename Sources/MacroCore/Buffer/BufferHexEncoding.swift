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
   * buffer.writeHexString("48656c6c6f")
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
   *   - hexString: A hex encoded string, no spaces etc allowed between the
   *                bytes.
   * - Returns: true if successful, false if the input is invalid
   */
  @inlinable
  @discardableResult
  mutating func writeHexString<S: StringProtocol>(_ hexString: S) -> Bool {
    guard !hexString.isEmpty else { return true }
    
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
