//
//  BufferStrings.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2024 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.Data
#endif

public enum DataDecodingError: Swift.Error {
  case failedToDecodeHexString
  case failedToDecodeBase64
}
public enum DataEncodingError: Swift.Error {
  case failedToReadData
}

public extension Buffer {
  
  /**
   * Initialize the Buffer with the UTF-8 data in the String.
   */
  @inlinable
  init(_ string: String) {
    self.init(string.utf8)
  }
  
  /**
   * Initialize the Buffer with the UTF-8 data in the String.
   */
  @inlinable
  init<S: StringProtocol>(_ string: S) {
    self.init(string.utf8)
  }
}

public extension Buffer {
  
  @inlinable
  func indexOf(_ string: String, _ byteOffset: Int = 0) -> Int {
    return indexOf(string.utf8, byteOffset)
  }
}

#if canImport(Foundation)

public extension Buffer {
  
  @inlinable
  func indexOf(_ string: String, _ byteOffset: Int = 0,
               _ encoding: String.Encoding = .utf8) -> Int
  {
    guard let data = string.data(using: encoding) else { return -1 }
    return indexOf(data, byteOffset)
  }

  
  @inlinable
  func indexOf(_ string: String, _ byteOffset: Int = 0,
               _ encoding: String) -> Int
  {
    guard let needle = try? Buffer.from(string, encoding) else {
      return -1
    }
    return indexOf(needle, byteOffset)
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
  static func from(_ string: String, _ encoding: String.Encoding = .utf8)
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
                                      _ encoding: String.Encoding = .utf8)
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
   * Example:
   * ```swift
   * let buffer = try Buffer.from("48656c6c6f", "hex")
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   *
   * - Parameters:
   *   - string:   The string to convert to a Buffer.
   *   - encoding: The requested encoding, e.g. 'utf8' or 'hex'.
   * - Returns: A Buffer representing the string in the given encoding.
   * - Throws: CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  static func from<S: StringProtocol>(_ string: S, _ encoding: String) throws
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
        return try from(string, .encodingWithName(encoding))
    }
  }
  
  /**
   * Returns true if the string argument represents a valid encoding, i.e.
   * if it can be used in the `Buffer.toString` method.
   *
   * Example:
   * ```swift
   * Buffer.isEncoding("utf8")        // true
   * Buffer.isEncoding("hex")         // true
   * Buffer.isEncoding("base64")      // true
   * Buffer.isEncoding("alwaysright") // false
   * ```
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
   * Example:
   * ```swift
   * let buffer = Buffer("Hello".utf8)
   * let string = try buffer.toString("hex")
   * // "48656c6c6f"
   * ```
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

#endif // canImport(Foundation)
