//
//  Promise.swift
//  Macro
//
//  Created by Helge Heß on 6/8/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import struct   NIO.EventLoopPromise
import class    NIO.EventLoopFuture
import protocol NIO.EventLoop
import class    NIO.NIOThreadPool
import enum     NIO.ChannelError
import class    MacroCore.MacroCore
import enum     MacroCore.CharsetConversionError
import struct   MacroCore.Buffer
import enum     MacroCore.MacroError
import struct   Foundation.Data
import struct   Foundation.URL

/**
 * Node also provides a Promise based fs API:
 * https://nodejs.org/dist/latest-v13.x/docs/api/fs.html#fs_fs_promises_api
 *
 * Those only really start to make sense w/ async/await, but since NIO is
 * promise based anyways ...
 */
public enum promise {
}

public extension promise {
  
  // TODO: Complete me :-)
  // Note: We dupe the imp, to avoid the extra promise overhead ¯\_(ツ)_/¯
  
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String) -> EventLoopFuture<Buffer>
  {
    let module    = MacroCore.shared.retain()
    let eventLoop = module.fallbackEventLoop(eventLoop)
    let promise   = eventLoop.makePromise(of: Buffer.self)

    FileSystemModule.threadPool.submit { shouldRun in
      defer { module.release() }
      
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        return promise.fail(ChannelError.ioOnClosedChannel)
      }
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        promise.succeed(Buffer(data))
      }
      catch {
        promise.fail(error)
      }
    }
    
    return promise.futureResult
  }

  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       _   encoding : String.Encoding) -> EventLoopFuture<String>
  {
    let module    = MacroCore.shared.retain()
    let eventLoop = module.fallbackEventLoop(eventLoop)
    let promise   = eventLoop.makePromise(of: String.self)

    FileSystemModule.threadPool.submit { shouldRun in
      defer { module.release() }
      
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        return promise.fail(ChannelError.ioOnClosedChannel)
      }

      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard let s = String(bytes: data, encoding: encoding) else {
          promise.fail(CharsetConversionError
                         .failedToConverData(encoding: encoding))
          return
        }
        promise.succeed(s)
      }
      catch {
        promise.fail(error)
      }
    }
    
    return promise.futureResult
  }
  
  @inlinable
  static func readFile(on eventLoop : EventLoop? = nil,
                       _       path : String,
                       _   encoding : String) -> EventLoopFuture<String>
  {
    return readFile(on: eventLoop, path, .encodingWithName(encoding))
  }
  
  @inlinable
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _ path: String, _ buffer: Buffer)
              -> EventLoopFuture<Void>
  {
    return writeFile(on: eventLoop, path, buffer.data)
  }

  @inlinable
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _       path : String,
                        _     string : String,
                        _   encoding : String.Encoding = .utf8)
              -> EventLoopFuture<Void>
  {
    guard let data = string.data(using: encoding) else {
      let eventLoop = MacroCore.shared.fallbackEventLoop(eventLoop)
      let promise   = eventLoop.makePromise(of: Void.self)
      promise.fail(CharsetConversionError
                     .failedToConverData(encoding: encoding))
      return promise.futureResult
    }
    return writeFile(path, data)
  }
  
  @inlinable
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _       path : String,
                        _     string : String,
                        _   encoding : String)
              -> EventLoopFuture<Void>
  {
    return writeFile(on: eventLoop, path, string, .encodingWithName(encoding))
  }
  
  @inlinable
  static func writeFile(on eventLoop : EventLoop? = nil,
                        _       path : String,
                        _       data : Data) -> EventLoopFuture<Void>
  {
    let module    = MacroCore.shared.retain()
    let eventLoop = module.fallbackEventLoop(eventLoop)
    let promise   = eventLoop.makePromise(of: Void.self)

    FileSystemModule.threadPool.submit { shouldRun in
      defer { module.release() }
      
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        return promise.fail(ChannelError.ioOnClosedChannel)
      }

      do {
        try writeFileSync(path, data)
        promise.succeed( () )
      }
      catch {
        promise.fail(error)
      }
    }
    return promise.futureResult
  }
}

public extension promise {

  @inlinable
  static func readdir(on eventLoop : EventLoop? = nil,
                      _       path : String)
              -> EventLoopFuture<[ String ]>
  {
    let module    = MacroCore.shared.retain()
    let eventLoop = module.fallbackEventLoop(eventLoop)
    let promise   = eventLoop.makePromise(of: [ String ].self)

    FileSystemModule.threadPool.submit { shouldRun in
      defer { module.release() }
      
      guard case shouldRun = NIOThreadPool.WorkItemState.active else {
        return promise.fail(ChannelError.ioOnClosedChannel)
      }
      
      do {
        promise.succeed(try readdirSync(path))
      }
      catch {
        promise.fail(error)
      }
    }
    return promise.futureResult
  }
}
