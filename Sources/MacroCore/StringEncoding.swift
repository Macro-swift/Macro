//
//  StringEncoding.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

@usableFromInline
internal let stringEncodingNames : Set<String> = [
  "utf8", "utf-8",
  "ascii",
  "iso2022jp",
  "isolatin1", "latin1", "iso-8859-1",
  "isolatin2", "latin2", "iso-8859-2",
  "japaneseeuc",
  "macosroman", "macos",
  "nextstep",
  "nonlossyascii",
  "shiftjis",
  "symbol",
  "unicode",
  "utf-16", "utf16",
  "utf-32", "utf32"
  // TODO: add the rest
]

public extension String.Encoding {
  
  @inlinable static func isEncoding(_ name: String) -> Bool {
    return stringEncodingNames.contains(name)
  }
  
  @inlinable
  static func encodingWithName(_ name: String) -> String.Encoding {
    let lc = name.lowercased()
    switch lc {
      case "utf8", "utf-8"                     : return .utf8
      case "ascii"                             : return .ascii
      case "iso2022jp"                         : return .iso2022JP
      case "isolatin1", "latin1", "iso-8859-1" : return .isoLatin1
      case "isolatin2", "latin2", "iso-8859-2" : return .isoLatin2
      case "japaneseeuc"                       : return .japaneseEUC
      case "macosroman", "macos"               : return .macOSRoman
      case "nextstep"                          : return .nextstep
      case "nonlossyascii"                     : return .nonLossyASCII
      case "shiftjis"                          : return .shiftJIS
      case "symbol"                            : return .symbol
      case "unicode"                           : return .unicode
      case "utf-16", "utf16"                   : return .utf16
      case "utf-32", "utf32"                   : return .utf32
      // TODO: add the rest
      default:
        process.emitWarning("Unexpected String encoding: '\(name)'",
                            name: #function)
        return .utf8
    }
  }
}

public enum CharsetConversionError: Swift.Error {
  case failedToConverData   (encoding: String.Encoding)
  case failedToConvertString(encoding: String.Encoding)
}
