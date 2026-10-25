//
//  BufferStrings.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
import struct Foundation.Data
#endif
import NIOCore

public enum DataDecodingError: Swift.Error, Equatable, Sendable {
  case failedToDecodeHexString
  case failedToDecodeBase64
}
public enum DataEncodingError: Swift.Error, Equatable, Sendable {
  case failedToReadData
}

/// Thrown on unknown encoding passed to e.g. ``Buffer/from(_:_:)-(_,String)``.
public struct UnknownEncodingError: Swift.Error, Equatable, Sendable {

  /// The encoding name that was not recognized.
  public let encoding: String

  @inlinable public init(_ encoding: String) { self.encoding = encoding }
}

public extension Buffer {
 
  /// Initialize the Buffer with the UTF-8 data in the String.
  @inlinable init(_ string: String) { self.init(string.utf8) }
  
  /// Initialize the Buffer with the UTF-8 data in the String.
  @inlinable init<S: StringProtocol>(_ string: S) { self.init(string.utf8) }

  @inlinable // avoids an alloc
  mutating func append(_ string: String) { byteBuffer.writeString(string) }

  @inlinable
  mutating func append<S: StringProtocol>(_ string: S) {
    byteBuffer.writeSubstring(Substring(string))
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
  func indexOf(_   string : String, _ byteOffset: Int = 0,
               _ encoding : String.Encoding = .utf8) -> Int
  {
    guard let data = string.data(using: encoding) else { return -1 }
    return indexOf(data, byteOffset)
  }

  
  @inlinable
  func indexOf(_   string : String, _ byteOffset: Int = 0,
               _ encoding : String) -> Int
  {
    guard let needle = try? Buffer.from(string, encoding) else { return -1 }
    return indexOf(needle, byteOffset)
  }
}

public extension Buffer {
  
  /// The supported binary encodings.
  enum BinaryEncoding: String, CaseIterable, Sendable {

    /// Two hex digits per byte, e.g. `48656c6c6f`.
    case hex

    /// Base64 with `=` padding.
    case base64

    /// URL-safe base64 without padding.
    case base64url

    /**
     * Case-insensitive init (both HEX and hex work).
     *
     * - Parameters:
     *   - rawValue: The name of the encoding, e.g. `"hex"`.
     */
    @inlinable
    public init?(rawValue: String) {
      switch rawValue.lowercased() {
        case "hex"       : self = .hex
        case "base64"    : self = .base64
        case "base64url" : self = .base64url
        default          : return nil
      }
    }
  }
  
  #if canImport(Foundation)
  /**
   * Creates a Buffer from the given string, in the given encoding (defaults to
   * UTF-8).
   * If the string cannot be represented in the encoding, it throws a
   * `CharsetConversionError`.
   *
   * - Parameters:
   *   - string:   The string to convert to a Buffer.
   *   - encoding: The requested encoding, defaults to `.utf8`.
   * - Returns:    A Buffer representing the string in the given encoding.
   * - Throws:     CharsetConversionError if the data could not be converted to
   *               a string.
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
  static func from<S>(_ string: S, _ encoding: String.Encoding = .utf8)
                throws -> Buffer
    where S: StringProtocol
  {
    guard let data = string.data(using: encoding) else {
      throw CharsetConversionError.failedToConverData(encoding: encoding)
    }
    return Buffer(data)
  }
  #endif //

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
   * - Throws: ``UnknownEncodingError`` if the encoding name is not known,
   *           CharsetConversionError if the string could not be converted,
   *           ``DataDecodingError`` for invalid hex or base64.
   */
  @inlinable
  static func from<S>(_ string: S, _ encoding: String) throws -> Buffer
    where S: StringProtocol
  {
    if let binaryEncoding = BinaryEncoding(rawValue: encoding) {
      return try from(string, binaryEncoding)
    }
    #if canImport(Foundation)
      guard let stringEncoding = String.Encoding.from(encoding) else {
        throw UnknownEncodingError(encoding)
      }
      return try from(string, stringEncoding)
    #else
      throw UnknownEncodingError(encoding)
    #endif
  }

  /**
   * Decodes a Buffer from a string in the given encoding.
   *
   * Example:
   * ```swift
   * let buffer = try Buffer.from("48656c6c6f", .hex)
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   *
   * - Parameters:
   *   - string:   The encoded string, e.g. a hex or base64 string.
   *   - encoding: The binary encoding of the string.
   * - Returns:    A Buffer with the decoded bytes.
   * - Throws:     ``DataDecodingError``
   */
  @inlinable
  static func from<S>(_ string: S, _ encoding: BinaryEncoding) throws -> Buffer
    where S: StringProtocol
  {
    switch encoding {
      case .hex:
        var buffer = Buffer(capacity: string.utf16.count / 2)
        guard buffer.writeHexString(string) else {
          throw DataDecodingError.failedToDecodeHexString
        }
        return buffer
      
      case .base64:
        #if canImport(Foundation)
        let s = String(string)
        if let data = Data(base64Encoded: s) { return Buffer(data) }

        // https://stackoverflow.com/questions/4080988/why-does-base64-encoding
        switch s.count % 4 {
          case 0: // should have decoded above
            throw DataDecodingError.failedToDecodeBase64
          case 1: // invalid base64
            throw DataDecodingError.failedToDecodeBase64
          case 2:
            if let data = Data(base64Encoded: s + "==") { return Buffer(data) }
          case 3:
            if let data = Data(base64Encoded: s + "=")  { return Buffer(data) }
          default:
            assertionFailure("Invalid % operation.")
        }
        #endif
        throw DataDecodingError.failedToDecodeBase64

      case .base64url:
        return try from(String(string.map {
          switch $0 {
            case "-" : return "+"
            case "_" : return "/"
            default  : return $0
          }
        }), .base64)
    }
  }

  /**
   * Decodes a Buffer from a string in the given encoding.
   *
   * Example:
   * ```swift
   * let buffer = try Buffer.from("48656c6c6f", "hex")
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   *
   * - Parameters:
   *   - string:   The encoded string, e.g. a hex or base64 string.
   *   - encoding: The encoding of the string (def: UTF-8).
   * - Returns:    A Buffer with the decoded bytes.
   * - Throws:     A `TypeError` ``JSError`` if the string is `nil`,
   *               ``UnknownEncodingError``, ``DataDecodingError``.
   */
  @inlinable
  static func from<S>(_ string: S?, _ encoding: String = "utf8") throws
                -> Buffer
    where S: StringProtocol
  {
    guard let string else {
      throw JSError("TypeError", "The first argument must be of type string.")
    }
    return try from(string, encoding)
  }

  /**
   * Decodes a Buffer from an optional string in the given encoding.
   *
   * Example:
   * ```swift
   * let buffer = try Buffer.from("48656c6c6f", .hex)
   * let string = try buffer.toString()
   * // "Hello"
   * ```
   *
   * - Parameters:
   *   - string:   The encoded string, e.g. a hex or base64 string.
   *   - encoding: The binary encoding of the string.
   * - Returns:    A Buffer with the decoded bytes.
   * - Throws:     A `TypeError` ``JSError`` if the string is `nil`,
   *               ``DataDecodingError`` for invalid data.
   */
  @inlinable
  static func from<S>(_ string: S?, _ encoding: BinaryEncoding) throws -> Buffer
    where S: StringProtocol
  {
    guard let string else {
      throw JSError("TypeError", "The first argument must be of type string.")
    }
    return try from(string, encoding)
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
    BinaryEncoding(rawValue: encoding) != nil 
    || String.Encoding.isEncoding(encoding)
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
   * - Throws: ``UnknownEncodingError`` if the encoding name is not known,
   *           CharsetConversionError if the data could not be converted to
   *           a string.
   */
  @inlinable
  func toString(_ encoding: String) throws -> String {
    if let binaryEncoding = BinaryEncoding(rawValue: encoding) {
      return toString(binaryEncoding)
    }
    guard let stringEncoding = String.Encoding.from(encoding) else {
      throw UnknownEncodingError(encoding)
    }
    return try toString(stringEncoding)
  }

  /**
   * Returns the contents of the Buffer as a string in the given encoding.
   *
   * Example:
   * ```swift
   * let buffer = Buffer("Hello".utf8)
   * let string = buffer.toString(.hex)
   * // "48656c6c6f"
   * ```
   *
   * - Parameters:
   *   - encoding: The encoding, e.g. `.hex` or `.base64`.
   * - Returns:    The encoded string.
   */
  @inlinable
  func toString(_ encoding: BinaryEncoding) -> String {
    switch encoding {
      case .hex       : return hexEncodedString()
      case .base64    : return data.base64EncodedString()
      case .base64url :
        var b64 = data.base64EncodedString()
        if let eqIdx = b64.firstIndex(of: "=") { b64 = String(b64[..<eqIdx]) }
        return String(b64.map {
          switch $0 {
            case "+" : return "-"
            case "/" : return "_"
            default  : return $0
          }
        })
    }
  }
}

#endif // canImport(Foundation)
