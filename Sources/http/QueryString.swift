//
//  QueryString.swift
//  Macro/Noze.io
//
//  Created by Helge Hess.
//  Copyright © 2016-2022 ZeeZide GmbH. All rights reserved.
//

import enum   MacroCore.process

#if canImport(Foundation)
import struct Foundation.CharacterSet
import class  Foundation.JSONEncoder
import class  Foundation.JSONSerialization
#endif // canImport(Foundation)

/**
 * Macro implementation of the Node `querystring` module.
 *
 * https://nodejs.org/api/querystring.html
 */
public enum QueryStringModule {}
public typealias querystring = QueryStringModule

public extension QueryStringModule {
  
#if canImport(Foundation)
  /**
   * Does URL percent decoding on the given string.
   *
   * Consider using `querystring.parse` instead.
   *
   * For example: `hello%20world` => `hello world`
   */
  @inlinable
  static func unescape<S: StringProtocol>(_ string: S) -> String {
    guard !string.isEmpty else { return "" }
    guard let s = string.removingPercentEncoding else {
      assertionFailure("could not % unescape \(string)")
      process.emitWarning("could not % unescape a string")
      return ""
    }
    return s
  }
  
  /**
   * Does URL percent encoding on the given string.
   *
   * Consider using `querystring.stringify` instead.
   *
   * For example: `hello world` => `hello%20world`
   */
  @inlinable
  static func escape<S: StringProtocol>(_ string: S,
                                        allowedCharacters: CharacterSet)
              -> String
  {
    guard !string.isEmpty else { return "" }
    guard let s = string
      .addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
      assertionFailure("could not % escape \(string)")
      process.emitWarning("could not % escape a string")
      return ""
    }
    return s
  }
  /**
   * Does URL percent encoding on the given string.
   *
   * Consider using `querystring.stringify` instead.
   *
   * For example: `hello world` => `hello%20world`
   */
  @inlinable
  static func escape(_ string: String) -> String {
    return escape(string, allowedCharacters: .urlQueryAllowed)
  }
  /**
   * Does URL percent encoding on the given string.
   *
   * Consider using `querystring.stringify` instead.
   *
   * For example: `hello world` => `hello%20world`
   */
  @inlinable
  static func escape<S: StringProtocol>(_ string: S) -> String {
    return escape(string, allowedCharacters: .urlQueryAllowed)
  }
#endif // canImport(Foundation)

  @inlinable
  static func decode(_ string           : String,
                     separator          : Character = "&",
                     pairSeparator      : Character = "=",
                     emptyValue         : Any       = "",
                     zopeFormats        : Bool      = true,
                     decodeURIComponent : (( String ) -> String) = unescape)
              -> [ String : Any ]
  {
    return parse(string, separator: separator, pairSeparator: pairSeparator,
                 emptyValue: emptyValue, zopeFormats: zopeFormats,
                 decodeURIComponent: decodeURIComponent)
  }
  
  /**
   * Produces a URL query strings for the given dictionary.
   *
   * For example:
   *
   *     let s = querystring.stringify([ "a": 5, "b": 42 ])
   *     assert(s == "a=5&b=42")
   *
   */
  @inlinable
  static func stringify(_ object           : [ String : Any ]?,
                        separator          : Character = "&",
                        pairSeparator      : Character = "=",
                        encodeURIComponent : (( String ) -> String) = escape)
              -> String
  {
    guard let object = object else { return "" }
    
    var ms = ""
    ms.reserveCapacity(object.count * 24)
    
    func appendPair(_ key: String, _ value: String) {
      // TODO: Accessing `encodedURIComponent` in here breaks Swift 5.0
      ms.append(key)
      if !value.isEmpty {
        ms.append(pairSeparator)
        ms.append(value)
      }
    }
    
    for ( key, value ) in object {
      // TODO: improve
      
      if !ms.isEmpty { ms.append(separator) }
      
      let encodedKey = encodeURIComponent(key)
      
      switch value {
        case let string as String:
          appendPair(encodedKey, encodeURIComponent(string))
        case let strings as [ String ]:
          for string in strings {
            appendPair(encodedKey, encodeURIComponent(string))
          }
        case let values as [ Any ]:
          for value in values {
            appendPair(encodedKey, encodeURIComponent(String(describing:value)))
          }
        default:
          appendPair(encodedKey, encodeURIComponent(String(describing: value)))
      }
    }
    return ms
  }
  @inlinable
  static func stringify(_ object: String?,
                        encodeURIComponent : (( String ) -> String) = escape)
              -> String
  {
    guard let string = object, !string.isEmpty else { return "" }
    return encodeURIComponent(string)
  }

  @inlinable
  static func stringify(_ object : Any?,
                        encodeURIComponent : (( String ) -> String) = escape)
              -> String
  {
    guard let object = object else { return "" }
    if let dict = object as? [ String : Any ] {
      return stringify(dict, encodeURIComponent: encodeURIComponent)
    }
    else if let string = object as? String {
      return stringify(string, encodeURIComponent: encodeURIComponent)
    }
    else {
      return stringify(String(describing: object),
                       encodeURIComponent: encodeURIComponent)
    }
  }

#if canImport(Foundation)
  /**
   * Produces a URL query strings for the given `Encodable` object.
   *
   * For example:
   *
   *     struct Query: Encodable {
   *       let a = 5
   *       let b = 42
   *     }
   *     let s = querystring.stringify(Query())
   *     assert(s == "a=5&b=42")
   *
   * Throws an Error if the object encoding failed.
   */
  static func _stringify<T: Encodable>(_ object: T) throws -> String {
    // expensive, but useful :-)
    let jsonData = try makeEncoder().encode(object)
    let json     = try JSONSerialization.jsonObject(with: jsonData)
    return stringify(json)
  }
  /**
   * Produces a URL query strings for the given `Encodable` object.
   *
   * For example:
   *
   *     struct Query: Encodable {
   *       let a = 5
   *       let b = 42
   *     }
   *     let s = querystring.stringify(Query())
   *     assert(s == "a=5&b=42")
   *
   */
  @inlinable
  static func stringify<T: Encodable>(_ object: T) -> String {
    do {
      return try _stringify(object)
    }
    catch {
      process.emitWarning(error, name: "could JSON encode encodable object")
      return ""
    }
  }
#endif // canImport(Foundation)

  
  // MARK: - Parsing

  /**
   * Parses a URL query string, like "a=5&b=10" into a dictionary,
   * unescaping the components first.
   *
   * Example:
   *
   *     let values = querystring.parse("a=5&b=10")
   *     assert(values["a"] as? String == "5")
   *     assert(values["b"] as? String == "10")
   *
   * This supports a set of "Zope" style extras, which can be disabled by the
   * `zopeFormats` parameter. Checkout `parseZopeQueryParameter` for details.
   */
  @inlinable
  static func parse(_ string           : String,
                    separator          : Character = "&",
                    pairSeparator      : Character = "=",
                    emptyValue         : Any       = "",
                    zopeFormats        : Bool      = true,
                    decodeURIComponent : (( String ) -> String) = unescape)
              -> [ String : Any ]
  {
    guard !string.isEmpty else { return [:] }
    
    var qp = Dictionary<String, Any>()
    
    let pairs = string.split(separator: separator,
                             omittingEmptySubsequences: true)
    for pair in pairs {
      let pairParts = pair.split(separator: pairSeparator,
                                 maxSplits: 1,
                                 omittingEmptySubsequences: true)
      guard !pairParts.isEmpty else { continue }
      
      // check key and whether it contains Zope style formats
      
      let keyPart = pairParts[0]
      let fmtIdx  = keyPart.firstIndex(of: ":")
      let key     : String
      let formats : String?
      
      if zopeFormats && fmtIdx != nil  {
        key     = String(keyPart[keyPart.startIndex..<fmtIdx!])
        formats =
          String(keyPart[keyPart.index(after: fmtIdx!)..<keyPart.endIndex])
      }
      else {
        key     = String(keyPart)
        formats = nil
      }
      
      // check whether there is a key but no value ...
      
      if pairParts.count == 1 {
        if qp[key] == nil {
          qp[key] = emptyValue
        }
        continue
      }
      
      // get value
      
      let rawValue = decodeURIComponent(String(pairParts[1]))
      let value : Any
      
      if let formats = formats {
        // TODO: record, list, tuple, array:
        //       e.g.: person.age:int:record
        if formats.hasPrefix("list") || formats.hasPrefix("tuple") ||
           formats.hasPrefix("array")
        {
          process.emitWarning("list parameter not yet implement: \(formats)")
          value = rawValue
        }
        else if formats.hasPrefix("record") {
          process.emitWarning("record parameter not yet implement: \(formats)")
          value = rawValue
        }
        else {
          if let zvalue = parseZopeQueryParameter(string: rawValue,
                                                  format: formats)
          {
            value = zvalue
          }
          else {
            continue // TBD: skip
          }
        }
      }
      else {
        value = rawValue
      }
      
      if let existingValue = qp[key] {
        var a : [ Any ]
        if let aa = existingValue as? [ Any ] {
          a = aa
        }
        else {
          a = [ Any ]()
          a.append(existingValue)
        }
        a.append(value)
        qp[key] = a
      }
      else {
        qp[key] = value
      }
    }
    
    return qp
  }

  /// Zope like value formatter
  ///
  /// As explained in
  /// [Passing Parameters to Scripts](http://www.faqs.org/docs/ZopeBook/ScriptingZope.html)
  ///
  /// You can annotate form names with "filters" to convert strings being
  /// passed in by browsers into objects, eg:
  ///
  ///     <input type="text" name="age:int" />
  ///
  /// When the browser submits the form, "age:int" will initially be stored
  /// as a string. This method will detect the ":int" suffix and create an
  /// Integer object keyed under 'age'. That is, you will be able to do this:
  ///
  ///     let age = qp["age"] as? Int
  ///
  /// The facility is quite powerful, eg filters can be nested.
  ///
  @inlinable
  static func parseZopeQueryParameter(string s: String, format: String) -> Any?
  {
    // TODO: date, tokens, required
    switch format {
      case "int", "long": return Int(s)
      case "float":       return Float(s)
      case "string":      return s
      
      case "text":
        return String(s.filter { $0 != "\r" })
      
      case "lines":
        let lines = s.filter({ $0 != "\r" }).split(separator: "\n")
        return lines.map { String($0) }
      
      case "boolean":
        switch s {
          case "1", "Y", "y", "yes", "YES", "on", "ON": return true
          default: return false
        }
      
      case "ignore_empty":
        return s.isEmpty ? nil : s
      
      case "method", "action", "default_method", "default_action":
        return s
      
      default:
        process.emitWarning("Unsupported query value format: \(format)")
        return s
    }
  }
}

#if canImport(Foundation)
/// It is undocumented whether the encoder is threadsafe, so assume it is not.
fileprivate func makeEncoder() -> JSONEncoder {
  let encoder = JSONEncoder()
  if #available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *) {
    // According to https://github.com/NozeIO/MicroExpress/pull/13 the default
    // strategy is NeXTstep time.
    encoder.dateEncodingStrategy = .iso8601
  }
  return encoder
}
#endif // canImport(Foundation)
