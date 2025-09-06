//
//  NextTick.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2025 ZeeZide GmbH. All rights reserved.
//

import NIO

public extension MacroCore {
  
  /// Enqueue the given closure for later dispatch in the Q.
  @inlinable
  func nextTick(on eventLoop : EventLoop? = nil,
                _    execute : @escaping () -> Void)
  {
    // Node says that tick() is special in that it runs before IO events. Is the
    // same true for NIO?
    
    retain() // TBD: expensive? Do in here?
    
    let loop = eventLoop
            ?? MultiThreadedEventLoopGroup.currentEventLoop
            ?? eventLoopGroup.next()
    loop.execute {
      execute()
      self.release()
    }
  }

  /// Execute the given closure after the amount of milliseconds given.
  @inlinable
  func setTimeout(on    eventLoop : EventLoop? = nil,
                  _  milliseconds : Int,
                  _       execute : @escaping () -> Void)
  {
    // TBD: what is the proper place for this?
    // TODO: in JS this also allows for a set of arguments to be passed to the
    //       callback (but who uses this facility?)
    
    retain() // TBD: expensive? Do in here?
    
    let loop = eventLoop
            ?? MultiThreadedEventLoopGroup.currentEventLoop
            ?? eventLoopGroup.next()
    
    loop.scheduleTask(in: .milliseconds(Int64(milliseconds))) {
      execute()
      self.release()
    }
  }
  
}

/// Enqueue the given closure for later dispatch in the Q.
@inlinable
public func nextTick(on eventLoop : EventLoop? = nil,
                     _    execute : @escaping () -> Void)
{
  MacroCore.shared.nextTick(on: eventLoop, execute)
}

/// Execute the given closure after the amount of milliseconds given.
@inlinable
public func setTimeout(on    eventLoop : EventLoop? = nil,
                       _  milliseconds : Int,
                       _       execute : @escaping () -> Void)
{
  MacroCore.shared.setTimeout(on: eventLoop, milliseconds, execute)
}
