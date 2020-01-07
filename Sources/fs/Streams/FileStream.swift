//
//  FileStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class    MacroCore.MacroCore
import enum     MacroCore.EventListenerSet
import protocol MacroCore.ErrorEmitterType
import protocol MacroCore.ErrorEmitterTarget
import struct   NIO.ByteBufferAllocator
import class    NIO.NIOFileHandle
import protocol NIO.EventLoop
import struct   NIO.NonBlockingFileIO

// TODO: a pipe/| implementation which does a `sendfile`?

public protocol FileStream: AnyObject, ErrorEmitterType, ErrorEmitterTarget {

  var eventLoop      : EventLoop                       { get }
  var path           : String                          { get }
  var fileHandle     : NIOFileHandle?                  { get set }
  var pending        : Bool                            { get }
  
  var allocator      : ByteBufferAllocator             { get }

  var readyListeners : EventListenerSet<Void>          { get set }
  var closeListeners : EventListenerSet<Void>          { get set }
  var openListeners  : EventListenerSet<NIOFileHandle> { get set }
}

internal extension FileStream {

  var fileIO : NonBlockingFileIO { return FileSystemModule.fileIO }

  func _clearFileListeners() {
    openListeners .removeAll()
    closeListeners.removeAll()
    readyListeners.removeAll()
  }
  
}

public extension FileStream {
  
  @inlinable var allocator : ByteBufferAllocator {
    return MacroCore.shared.allocator
  }
  
  @discardableResult
  @inlinable
  func onceOpen(execute: @escaping ( NIOFileHandle ) -> Void) -> Self {
    if let fileHandle = fileHandle { execute(fileHandle) }
    else { openListeners.once(execute) }
    return self
  }
  
  /// Note: onOpen is the same as onceOpen
  @discardableResult @inlinable
  func onOpen(execute: @escaping ( NIOFileHandle ) -> Void) -> Self {
    return onceOpen(execute: execute)
  }
  
  @discardableResult @inlinable
  func onceReady(execute: @escaping () -> Void) -> Self {
    if !pending && fileHandle != nil { execute() }
    else { readyListeners.once(execute) }
    return self
  }
  
  /// Note: onReady is the same as onceReady
  @discardableResult @inlinable
  func onReady(execute: @escaping () -> Void) -> Self {
    return onceReady(execute: execute)
  }
  
  @discardableResult @inlinable
  func onceClose(execute: @escaping () -> Void) -> Self {
    closeListeners.once(execute)
    return self
  }
  
  /// Note: onClose is the same as onceClose
  @discardableResult @inlinable
  func onClose(execute: @escaping () -> Void) -> Self {
    return onceClose(execute: execute)
  }
}
