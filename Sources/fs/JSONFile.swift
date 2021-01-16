//
//  JSONFile.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.EventLoop
import class    NIO.NIOThreadPool
import enum     NIO.ChannelError
import class    MacroCore.MacroCore
import struct   Foundation.Data
import struct   Foundation.URL
import class    Foundation.JSONSerialization
import class    Foundation.JSONEncoder
import class    Foundation.JSONDecoder

/**
 * The Macro jsonfile module exports.
 */
public enum JSONFileModule {
}

public extension JSONFileModule {
  // Note: Why not use fs.readFile etc? Because we want to serialize/deserialize
  //       on the background thread.
  
  /**
   * Reads a file as JSON.
   *
   * This uses Foundation `JSONSerialization`, the returned objects are the
   * respective Swift objects wrapped in `Any`.
   *
   * The JSON parsing happens on the I/O thread (`fs.threadPool`).
   *
   * Example:
   *
   *     jsonfile.readFile("/tmp/myfile.json) { error, value in
   *       if let error = error {
   *         console.error("loading failed:", error)
   *       }
   *       else {
   *         print("Loaded JSON:", value)
   *       }
   *     }
   *
   * - Parameters:
   *   - eventLoop: The NIO EventLoop to call the callback on. Defaults to the
   *                current EventLoop, if available.
   *   - path:      The path of the file to read from.
   *   - options:   The `JSONSerialization.ReadingOptions`, defaults to none
   *   - yield:     Callback which is called when the reading and decoding
   *                succeeded or failed. The first argument is the Error if one
   *                occurred, the second argument the JSON objects read (or the
   *                error).
   */
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       options      : JSONSerialization.ReadingOptions = [],
                       yield        : @escaping ( Swift.Error?, Any ) -> Void)
              -> Void
  {
    let module = MacroCore.shared.retain()
    let loop   = module.fallbackEventLoop(eventLoop)
    
    FileSystemModule.threadPool.submit { shouldRun in
      let result      : Any
      let resultError : Swift.Error?
      
      if case shouldRun = NIOThreadPool.WorkItemState.active {
        do {
          let data = try Data(contentsOf: URL(fileURLWithPath: path))
          let json = try JSONSerialization.jsonObject(with: data,
                                                      options: options)
          result      = json
          resultError = nil
        }
        catch {
          result      = error
          resultError = error
        }
      }
      else {
        result      = ChannelError.ioOnClosedChannel
        resultError = ChannelError.ioOnClosedChannel
      }
      
      loop.execute {
        yield(resultError, result)
        module.release()
      }
    }
  }

  /**
   * Writes JSON objects to a file.
   *
   * This uses Foundation `JSONSerialization`, the expected objects are the
   * respective Swift objects wrapped in `Any`.
   * There is also a `Codable` version of `writeFile`.
   *
   * The JSON generation happens on the I/O thread (`fs.threadPool`).
   *
   * Example:
   *
   *     try jsonfile.writeFile("/tmp/myfile.json", [ "key": "value" ]) { err in
   *       if let err = err {
   *         print("Writing failed:", err)
   *       }
   *     }
   *
   * - Parameters:
   *   - eventLoop: The NIO EventLoop to call the callback on. Defaults to the
   *                current EventLoop, if available.
   *   - path:      The path of the file to write to.
   *   - json:      The JSON objects representing the structure to write.
   *   - options:   The `JSONSerialization.WritingOptions`, defaults to none
   *   - yield:     Callback which is called when the encoding and writing
   *                succeeded or failed. The first argument carries the Error
   *                if one occurred, or nil.
   */
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _       path : String,
                        _       json : Any,
                        options      : JSONSerialization.WritingOptions = [],
                        yield        : @escaping ( Swift.Error? ) -> Void)
              -> Void
  {
    let module = MacroCore.shared.retain()
    let loop   = module.fallbackEventLoop(eventLoop)

    FileSystemModule.threadPool.submit { shouldRun in
      let resultError : Swift.Error?
      
      if case shouldRun = NIOThreadPool.WorkItemState.active {
        do {
          let data = try JSONSerialization.data(withJSONObject: json,
                                                options: options)
          try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
          resultError = nil
        }
        catch {
          resultError = error
        }
      }
      else {
        resultError = ChannelError.ioOnClosedChannel
      }
      
      loop.execute {
        yield(resultError)
        module.release()
      }
    }
  }

  /**
   * Writes JSON objects to a file.
   *
   * This uses Foundation `JSONEncoder`, the expected objects are Swift values
   * conforming to the Swift `Encodable` protocol.
   *
   * The JSON generation happens on the I/O thread (`fs.threadPool`).
   *
   * Example:
   *
   *     try jsonfile.writeFile("/tmp/myfile.json", [ "key": "value" ]) { err in
   *       if let err = err {
   *         print("Writing failed:", err)
   *       }
   *     }
   *
   * - Parameters:
   *   - eventLoop: The NIO EventLoop to call the callback on. Defaults to the
   *                current EventLoop, if available.
   *   - path:      The path of the file to write to.
   *   - json:      The `Encodable` JSON objects to write.
   *   - options:   The `JSONSerialization.WritingOptions`, defaults to none
   *   - yield:     Callback which is called when the encoding and writing
   *                succeeded or failed. The first argument carries the Error
   *                if one occurred, or nil.
   */
  static func writeFile<T>(on eventLoop : EventLoop? = nil,
                           _       path : String,
                           _       json : T,
                           options      : JSONSerialization.WritingOptions = [],
                           yield        : @escaping ( Swift.Error? ) -> Void)
              -> Void
              where T: Encodable
  {
    let module = MacroCore.shared.retain()
    let loop   = module.fallbackEventLoop(eventLoop)

    FileSystemModule.threadPool.submit { shouldRun in
      let resultError : Swift.Error?
      
      if case shouldRun = NIOThreadPool.WorkItemState.active {
        do {
          let data = try JSONEncoder().encode(json)
          try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
          resultError = nil
        }
        catch {
          resultError = error
        }
      }
      else {
        resultError = ChannelError.ioOnClosedChannel
      }
      
      loop.execute {
        yield(resultError)
        module.release()
      }
    }
  }

  /**
   * Reads a file as JSON.
   *
   * This uses Foundation `JSONSerialization`, the returned objects are the
   * respective Swift objects wrapped in `Any`.
   *
   * Example:
   *
   *     let json = try jsonfile.readFileSync("/tmp/myfile.json)
   *     print("Loaded JSON:", json)
   *
   * - Parameters:
   *   - path:    The path of the file to read from.
   *   - options: The `JSONSerialization.ReadingOptions`, defaults to none
   */
  @inlinable
  static func readFileSync(_  path : String,
                           options : JSONSerialization.ReadingOptions = [])
                throws -> Any
  {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let json = try JSONSerialization.jsonObject(with: data, options: options)
    return json
  }
  
  /**
   * Writes JSON objects to a file.
   *
   * This uses Foundation `JSONSerialization`, the expected objects are the
   * respective Swift objects wrapped in `Any`.
   * There is also a `Codable` version of `writeFile`.
   *
   * Example:
   *
   *     try jsonfile.writeFileSync("/tmp/myfile.json", [ "key": "value" ]
   *
   * - Parameters:
   *   - path:    The path of the file to write to.
   *   - json:    The JSON objects representing the structure to write.
   *   - options: The `JSONSerialization.WritingOptions`, defaults to none
   */
  @inlinable
  static func writeFileSync(_  path : String,
                            _  json : Any,
                            options : JSONSerialization.WritingOptions = [])
                throws
  {
    let data = try JSONSerialization.data(withJSONObject: json,
                                          options: options)
    try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
  }
  
  /**
   * Writes JSON objects to a file.
   *
   * This uses Foundation `JSONEncoder`, the expected objects are Swift values
   * conforming to the Swift `Encodable` protocol.
   *
   * Example:
   *
   *     try jsonfile.writeFile("/tmp/myfile.json", [ "key": "value" ]) { err in
   *       if let err = err {
   *         print("Writing failed:", err)
   *       }
   *     }
   *
   * - Parameters:
   *   - path:      The path of the file to write to.
   *   - json:      The `Encodable` JSON objects to write.
   *   - options:   The `JSONSerialization.WritingOptions`, defaults to none
   */
  @inlinable
  static func writeFileSync<T>(_  path : String,
                               _  json : T,
                               options : JSONSerialization.WritingOptions = [])
                throws
                where T: Encodable
  {
    let data = try JSONEncoder().encode(json)
    try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
  }
}
