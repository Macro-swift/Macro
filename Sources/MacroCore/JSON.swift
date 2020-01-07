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
import struct NIO.ByteBuffer

public enum JSON {}

/**
 * Node like API for JSON parsing.
 *
 * The functions return what `JSONSerialization` returns, i.e. property list objects.
 */
public extension JSON {
  
  @inlinable
  static func parse(_ string: Swift.String) -> Any? {
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
  static func parse(_ bytes: ByteBuffer) -> Any? {
    guard bytes.readableBytes > 0 else { return nil }
    
    let data = bytes.getData(at: bytes.readerIndex, length: bytes.readableBytes,
                             byteTransferStrategy: .noCopy)
    guard let data1 = data else {
      process.emitWarning("could not extract data from ByteBuffer",
                          name: "macro.json")
      assert(data != nil, "could not extract data from ByteBuffer")
      return nil
    }
    return parse(data1)
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
public extension JSON {
  
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

public let _defaultJSONOptions        : JSONSerialization.WritingOptions
                                      = [ .sortedKeys ]
public let _defaultJSONEncoderOptions : JSONEncoder.OutputFormatting
                                      = [ .sortedKeys ]


// MARK: - JSON Streams

public extension WritableStreamType where WritablePayload == ByteBuffer,
                                          Self : ErrorEmitterTarget
{

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

  @inlinable
  func writeJSON(_ string : String?,
                 whenDone : @escaping () -> Void = {}) -> Bool
  {
    return write(string ?? "null", whenDone: whenDone)
  }
}
