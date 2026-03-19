//
//  MainActorDefault.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

#if swift(>=6.0)
import NIO

public extension MacroCore {
  // HH: Preserve MainActor isolation if enqueued there.

  @inlinable
  func nextTick(on eventLoop: EventLoop? = nil,
                _ execute: @escaping @MainActor () -> Void)
  {
    retain()
    nextTick(on: eventLoop, {
      Task { @MainActor in execute(); self.release() }
    })
  }

  @inlinable
  func setTimeout(on eventLoop: EventLoop? = nil, _ milliseconds: Int,
                  _ execute: @escaping @MainActor () -> Void)
  { // TBD: This could just schedule on the mainActor if EL=nil?
    retain()
    setTimeout(on: eventLoop, milliseconds, {
      Task { @MainActor in execute(); self.release() }
    })
  }
}

@inlinable
public func nextTick(on eventLoop : EventLoop? = nil,
                     _ execute: @escaping @MainActor () -> Void)
{
  MacroCore.shared.nextTick(on: eventLoop, execute)
}

@inlinable
public func setTimeout(on eventLoop : EventLoop? = nil, _ milliseconds: Int,
                       _ execute: @escaping @MainActor () -> Void)
{
  MacroCore.shared.setTimeout(on: eventLoop, milliseconds, execute)
}

#endif
