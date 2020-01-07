//
//  AsyncWrapper.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/8/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class    Dispatch.DispatchQueue
import protocol NIO.EventLoop
import class    NIO.MultiThreadedEventLoopGroup
import class    NIO.NIOThreadPool
import enum     NIO.ChannelError
import class    MacroCore.MacroCore

extension FileSystemModule {
  
  ///
  /// This is useful for wrapping synchronous file APIs. Example:
  ///
  ///    public func readdir(path: String, cb: ( [ String ]? ) -> Void) {
  ///      module.Q._evalAsync(readdirSync, path, cb)
  ///    }
  ///

  @inlinable static
  func _evalAsync<ArgT>(on eventLoop: EventLoop? = nil,
                        _     f : @escaping ( ArgT ) throws -> Void,
                        _   arg : ArgT,
                        _ yield : @escaping ( Error? ) -> Void)
  {
    let module = MacroCore.shared.retain()
    FileSystemModule.threadPool.submit { shouldRun in
      let returnError : Error?
      
      if case shouldRun = NIOThreadPool.WorkItemState.active {
        do {
          try f(arg)
          returnError = nil
        }
        catch let error {
          returnError = error
        }
      }
      else {
        returnError = ChannelError.ioOnClosedChannel
      }
      
      module.fallbackEventLoop(eventLoop).execute {
        yield(returnError)
        module.release()
      }
    }
  }

  @inlinable static
  func _evalAsync<ArgT, RT>(on eventLoop: EventLoop? = nil,
                            _     f : @escaping ( ArgT ) throws -> RT,
                            _   arg : ArgT,
                            _ yield : @escaping ( Error?, RT? ) -> Void)
  {
    let module = MacroCore.shared.retain()
    FileSystemModule.threadPool.submit { shouldRun in
      let returnError : Error?
      let result      : RT?
      
      if case shouldRun = NIOThreadPool.WorkItemState.active {
        do {
          result = try f(arg)
          returnError = nil
        }
        catch let error {
          returnError = error
          result      = nil
        }
      }
      else {
        returnError = ChannelError.ioOnClosedChannel
        result = nil
      }
      
      module.fallbackEventLoop(eventLoop).execute {
        yield(returnError, result)
        module.release()
      }
    }
  }
}
