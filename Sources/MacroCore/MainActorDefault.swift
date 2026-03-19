//
//  MainActorDefault.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

#if swift(>=5.5) && canImport(_Concurrency)
import NIO

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public extension MacroCore {
  // HH: Preserve MainActor isolation if enqueued there.

  @inlinable
  func nextTick(on eventLoop: EventLoop? = nil,
                mainActor: @escaping @MainActor () -> Void)
  {
    retain()
    nextTick(on: eventLoop, {
      Task { @MainActor in mainActor(); self.release() }
    })
  }

  @inlinable
  func setTimeout(on eventLoop: EventLoop? = nil, _  milliseconds: Int,
                  mainActor: @escaping @MainActor () -> Void)
  { // TBD: This could just schedule on the mainActor if EL=nil?
    retain()
    setTimeout(on: eventLoop, milliseconds, {
      Task { @MainActor in mainActor(); self.release() }      
    })
  }
}

@inlinable
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func nextTick(on eventLoop : EventLoop? = nil,
                     mainActor execute: @escaping @MainActor () -> Void)
{
  MacroCore.shared.nextTick(on: eventLoop, mainActor: execute)
}

@inlinable
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public func setTimeout(on eventLoop : EventLoop? = nil, _ milliseconds: Int,
                       mainActor execute:@escaping @MainActor () -> Void)
{
  MacroCore.shared.setTimeout(on: eventLoop, milliseconds, mainActor: execute)
}

#endif
