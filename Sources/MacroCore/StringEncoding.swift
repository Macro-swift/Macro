//
//  StringEncoding.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
import Foundation

public extension String.Encoding {

  /**
   * Looks up a String encoding by a Node style name, e.g. "utf8" or
   * "latin1" (case insensitive).
   *
   * - Parameters:
   *   - name:   The name of the encoding, e.g. "utf8".
   * - Returns:  The String encoding, or `nil` if the name is not known.
   */
  @inlinable
  static func from(_ name: String) -> String.Encoding? {
    switch name.lowercased() {
      case "utf8", "utf-8"                     : .utf8
      case "ascii"                             : .ascii
      case "iso2022jp"                         : .iso2022JP
      case "isolatin1", "latin1", "iso-8859-1" : .isoLatin1
      case "isolatin2", "latin2", "iso-8859-2" : .isoLatin2
      case "japaneseeuc"                       : .japaneseEUC
      case "macosroman", "macos"               : .macOSRoman
      case "nextstep"                          : .nextstep
      case "nonlossyascii"                     : .nonLossyASCII
      case "shiftjis"                          : .shiftJIS
      case "symbol"                            : .symbol
      case "unicode"                           : .unicode
      case "utf-16", "utf16"                   : .utf16
      case "utf-32", "utf32"                   : .utf32
      // TODO: add the rest
      default                                  : nil
    }
  }

  /// Returns true if the name is a known String encoding, e.g. "utf8".
  @inlinable
  static func isEncoding(_ name: String) -> Bool {
    String.Encoding.from(name) != nil
  }

  /**
   * Returns the String encoding with the given name, e.g. "utf8".
   *
   * If the name is not known, this emits a warning and returns the
   * `fallbackEncoding` (def: UTF-8)..
   */
  @inlinable
  static func encodingWithName(_           name : String,
                               fallbackEncoding : String.Encoding = .utf8)
              -> String.Encoding
  {
    if let encoding = String.Encoding.from(name) { return encoding }
    process
      .emitWarning("Unexpected String encoding: '\(name)'", name: #function)
    return fallbackEncoding
  }
}

public enum CharsetConversionError: Swift.Error {
  case failedToConverData   (encoding: String.Encoding)
  case failedToConvertString(encoding: String.Encoding)
}
#endif // canImport(Foundation)
