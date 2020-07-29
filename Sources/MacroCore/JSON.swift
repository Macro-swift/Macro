//
//  JSON.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import NIOFoundationCompat
import struct Foundation.Data
import class  Foundation.JSONSerialization
import class  Foundation.JSONEncoder

public enum JSONModule {}
public typealias json = JSONModule

/**
 * Node like API for JSON parsing.
 *
 * The functions return what `JSONSerialization` returns, i.e. property list objects.
 */
public extension JSONModule {
  
  @inlinable
  static func parse<S: StringProtocol>(_ string: S) -> Any? {
    guard !string.isEmpty else { return nil }
    
    guard let data = string.data(using: .utf8) else {
      process.emitWarning("could not convert string to UTF8 data",
                          name: "macro.json")
      return nil
    }
    return parse(data)
  }

  @inlinable
  static func parse(_ data: Foundation.Data) -> Any? {
    guard !data.isEmpty else { return nil }
    
    do {
      return try JSONSerialization.jsonObject(with: data, options: [])
    }
    catch {
      process.emitWarning(error, name: "macro.json")
      return nil
    }
  }

  @inlinable
  static func parse(_ bytes: Buffer) -> Any? {
    guard !bytes.isEmpty else { return nil }
    return parse(bytes.data)
  }

  @inlinable
  static func parse<S>(_ bytes: S) -> Any?
                where S: Sequence, S.Element == UInt8
  {
    return parse(Data(bytes))
  }
}


/**
 * Node like API for JSON string generation.
 */
public extension JSONModule {
  
  @inlinable
  static func dataify(_ object : Any?,
                      options  : JSONSerialization.WritingOptions
                               = _defaultJSONOptions) -> Foundation.Data?
  {
    guard let o = object else { return "null".data(using: .utf8) }
    
    do {
      return try JSONSerialization.data(withJSONObject: o, options: options)
    }
    catch {
      process.emitWarning(error, name: "macro.json")
      return nil
    }
  }
  
  @inlinable
  static func stringify(_ object: Any?,
                        options: JSONSerialization.WritingOptions
                          = _defaultJSONOptions) -> Swift.String?
  {
    guard let o    = object                              else { return "null" }
    guard let data = dataify(o, options: options)        else { return nil    }
    guard let s    = String(data: data, encoding: .utf8) else {
      process.emitWarning("could not extract UTF-8 string from JSON data",
                          name: "macro.json")
      assertionFailure("could not extract UTF-8 string from JSON data")
      return nil
    }
    return s
  }
  
  
  // MARK: - Encodable versions

  @inlinable
  static func dataify<C: Encodable>(_ object : C?,
                                    outputFormatting:
                                      JSONEncoder.OutputFormatting
                                      = _defaultJSONEncoderOptions)
              -> Foundation.Data?
  {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = outputFormatting
      return try encoder.encode(object)
    }
    catch {
      process.emitWarning(error, name: "macro.json")
      return nil
    }
  }

  @inlinable
  static func stringify<C: Encodable>(_ object: C?,
                                      outputFormatting:
                                        JSONEncoder.OutputFormatting
                                        = _defaultJSONEncoderOptions)
              -> Swift.String?
  {
    guard let o = object else { return "null" }
    guard let data = dataify(o, outputFormatting: outputFormatting) else {
      return nil
    }
    guard let s = String(data: data, encoding: .utf8) else {
      process.emitWarning("could not extract UTF-8 string from JSON data",
                          name: "macro.json")
      assertionFailure("could not extract UTF-8 string from JSON data")
      return nil
    }
    return s
  }
}

// Public because those are used as default arguments:

public let _defaultJSONOptions : JSONSerialization.WritingOptions = {
  if #available(macOS 10.13, iOS 11, *) { return .sortedKeys }
  else                                  { return []          }
}()
public let _defaultJSONEncoderOptions : JSONEncoder.OutputFormatting = {
  if #available(macOS 10.13, iOS 11, *) { return .sortedKeys }
  else                                  { return []          }
}()


// MARK: - JSON Streams

public extension WritableStreamType where WritablePayload == Buffer,
                                          Self : ErrorEmitterTarget
{

  @discardableResult
  @inlinable
  func write<S: Encodable>(_ jsonObject: S,
                           outputFormatting:
                             JSONEncoder.OutputFormatting
                             = _defaultJSONEncoderOptions,
                           whenDone : @escaping () -> Void = {}) -> Bool
  {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = outputFormatting
      let data = try encoder.encode(jsonObject)
      return write(data, whenDone: whenDone)
    }
    catch {
      emit(error: error)
      return true // FIXME: HWM-Writable
    }
  }

  @discardableResult
  @inlinable
  func writeJSON(_ object : Any?,
                 options  : JSONSerialization.WritingOptions
                          = _defaultJSONOptions,
                 whenDone : @escaping () -> Void = {}) -> Bool
  {
    guard let o = object else { return write("null", whenDone: whenDone) }
    
    do {
      let data = try JSONSerialization.data(withJSONObject: o, options: options)
      return write(data, whenDone: whenDone)
    }
    catch {
      emit(error: error)
      return true // FIXME: HWM-Writable
    }
  }

  @discardableResult
  @inlinable
  func writeJSON(_ string : String?,
                 whenDone : @escaping () -> Void = {}) -> Bool
  {
    return write(string ?? "null", whenDone: whenDone)
  }
}
