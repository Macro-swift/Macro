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
  
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       options      : JSONSerialization.ReadingOptions = [],
                       yield        : @escaping ( Swift.Error?, Any ) -> Void)
              -> Void
  {
    let module = MacroCore.shared.retain()

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
      
      module.fallbackEventLoop(eventLoop).execute {
        yield(resultError, result)
        module.release()
      }
    }
  }
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _       path : String,
                        _       json : Any,
                        options      : JSONSerialization.WritingOptions = [],
                        yield        : @escaping ( Swift.Error? ) -> Void)
              -> Void
  {
    let module = MacroCore.shared.retain()

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
      
      module.fallbackEventLoop(eventLoop).execute {
        yield(resultError)
        module.release()
      }
    }
  }
  static func writeFile<T>(on eventLoop : EventLoop? = nil,
                           _       path : String,
                           _       json : T,
                           options      : JSONSerialization.WritingOptions = [],
                           yield        : @escaping ( Swift.Error? ) -> Void)
              -> Void
              where T: Encodable
  {
    let module = MacroCore.shared.retain()

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
      
      module.fallbackEventLoop(eventLoop).execute {
        yield(resultError)
        module.release()
      }
    }
  }

  static func readFileSync(_  path : String,
                           options : JSONSerialization.ReadingOptions = [])
                throws -> Any
  {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let json = try JSONSerialization.jsonObject(with: data, options: options)
    return json
  }
  
  static func writeFileSync(_  path : String,
                            _  json : Any,
                            options : JSONSerialization.WritingOptions = [])
                throws
  {
    let data = try JSONSerialization.data(withJSONObject: json,
                                          options: options)
    try data.write(to: URL(fileURLWithPath: path), options: [.atomic])
  }
  
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
