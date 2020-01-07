//
//  FileWriteStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class    NIO.NIOFileHandle
import protocol NIO.EventLoop
import struct   NIO.NonBlockingFileIO
import class    NIOConcurrencyHelpers.Lock
import class    MacroCore.MacroCore
import enum     MacroCore.WritableError
import class    MacroCore.WritableByteStream
import protocol MacroCore.WritableStreamType
import protocol MacroCore.WritableByteStreamType
import enum     MacroCore.EventListenerSet

@inlinable
public func createWriteStream(on eventLoop: EventLoop? = nil,
                              _ path: String,
                              flags: NIOFileHandle.Flags = .allowFileCreation())
            -> FileWriteStream
{
  let core = MacroCore.shared
  return FileWriteStream(eventLoop: core.fallbackEventLoop(eventLoop),
                         path: path, flags: flags)
}

fileprivate let retainLock      = Lock()
fileprivate var retainedStreams = [ ObjectIdentifier : FileWriteStream ]()

open class FileWriteStream: WritableByteStream, FileStream,
                            WritableStreamType, WritableByteStreamType
{
  public static var defaultWritableHighWaterMark = 64 * 1024
  
  enum StreamState: Equatable {
    case pending
    case open
    case ending
    case destroyed
  }
  
  public  let eventLoop  : EventLoop
  public  let path       : String
  public  var fileHandle : NIOFileHandle?
  public  let flags      : NIOFileHandle.Flags
  
  private var state      = StreamState.pending
  public  var pending    : Bool { return state == .pending }
  public  var destroyed  : Bool { return state == .destroyed }
  
  // The stream can end before it is even open!
  private var _didEnd = false
  
  override open var writableEnded: Bool {
    // not 100% right, it might be destroyed w/o a call to `end`?
    return _didEnd || (state == .ending || state == .destroyed)
  }
  override open var writableFinished: Bool {
    return destroyed
  }
  override open var writable : Bool {
    guard state == .pending || state == .open else { return false }
    return true
  }

  public var writableBuffer = [ ( bytes: ByteBuffer, whenDone: () -> () ) ]()
  
  @inlinable
  open var writableLength : Int {
    return writableBuffer.reduce(0) { $0 + $1.bytes.readableBytes }
  }
    
  @inlinable
  init(eventLoop: EventLoop, path: String, flags: NIOFileHandle.Flags) {
    self.eventLoop      = eventLoop
    self.path           = path
    self.flags          = flags
    super.init()
    writableHighWaterMark = FileWriteStream.defaultWritableHighWaterMark
  }
  
  // MARK: - End Stream
  
  open func end() {
    guard !_didEnd else { return }
    _didEnd = true
    corkCount = 0
    
    if pendingWrites > 0 || !writableBuffer.isEmpty {
      if state == .open {
        flushBuffer()
      }
    }
    else {
      destroy()
    }
  }
  
  open func destroy(_ error: Swift.Error? = nil) {
    if let error = error { emit(error: error) }
    writableBuffer.forEach { $0.whenDone() }
    writableBuffer.removeAll()
    close()
    
    finishListeners.emit()
    finishListeners.removeAll()
    
    // force destroy, regardless of close errors
    self.fileHandle = nil
    _clearListeners()
    
    state = .destroyed

    releaseIfNecessary()
  }
  
  private var pendingWrites = 0
  private var corkCount = 0
  
  override open var writableCorked : Bool {
    guard state == .open || state == .pending else { return false }
    return corkCount > 0
  }

  open func cork() {
    corkCount += 1
    assert(corkCount < 10, "excessive corking?")
  }
  open func uncork() {
    corkCount -= 1
    assert(corkCount >= 0)
    if corkCount < 1 {
      flushBuffer()
    }
  }

  @discardableResult
  open func write(_ bytes: ByteBuffer, whenDone: @escaping () -> Void) -> Bool {
    guard !writableEnded, state != .destroyed else {
      emit(error: WritableError.writableEnded)
      whenDone()
      return true
    }
    guard bytes.readableBytes > 0 else {
      whenDone()
      return writableLength < writableHighWaterMark
    }
    return _write(bytes, whenDone: whenDone)
  }
  
  func _write(_ bytes: ByteBuffer, whenDone: @escaping () -> Void) -> Bool {
    retainIfNecessary()

    if writableCorked && state != .ending {
      writableBuffer.append( ( bytes, whenDone ))
    }
    else if state == .pending {
      writableBuffer.append( ( bytes, whenDone ))
      open()
    }
    else if let fileHandle = fileHandle {
      if !writableBuffer.isEmpty {
        flushBuffer()
      }
      
      let count = bytes.readableBytes
      pendingWrites += count
      fileIO.write(fileHandle: fileHandle, buffer: bytes, eventLoop: eventLoop)
        .whenComplete { result in
          self.pendingWrites -= count
          assert(self.pendingWrites >= 0)
          
          if case .failure(let error) = result {
            self.emit(error: error)
          }

          whenDone()
          
          if self.pendingWrites < 1 {
            self._handleAllPendingDone()
          }
        }
    }
    else {
      assertionFailure("unexpected state \(state)")
      writableBuffer.append( ( bytes, whenDone ))
    }
    return writableLength < writableHighWaterMark
  }

  
  private func _handleAllPendingDone() {
    // TODO: shutdown if requested
    if !writableBuffer.isEmpty && state != .destroyed {
      return flushBuffer()
    }
    
    if state == .ending { // .end was called, buffer is empty, all writes done.
      destroy()
    }
    else { // ready for more writes
      drainListeners.emit()
    }
  }
  
  private var isRetained = false
  
  private func retainIfNecessary() {
    guard !isRetained else { return }
    isRetained = true
    retainLock.withLock {
      retainedStreams[ObjectIdentifier(self)] = self
    }
  }
  private func releaseIfNecessary() {
    guard isRetained else { return }
    isRetained = false
    _ = retainLock.withLock {
      retainedStreams.removeValue(forKey: ObjectIdentifier(self))
    }
  }
  
  private func open() {
    assert(fileHandle == nil)
    assert(pending)
    
    retainIfNecessary()
    
    fileIO.openFile(path: path, mode: .write, flags: flags,
                    eventLoop: eventLoop)
          .whenComplete(_handleOpenResult)
  }
  func _handleOpenResult(_ result: Result<NIOFileHandle, Swift.Error>) {
    switch result {
      case .success(let handle):
        assert(self.fileHandle == nil, "file handle already assigned!")
        try? self.fileHandle?.close()
        
        fileHandle = handle
        
        assert(state == .pending)
        state = .open
        
        openListeners .emit(handle)
        readyListeners.emit()
        openListeners .removeAll()
        readyListeners.removeAll()
        
        flushBuffer()

      case .failure(let error):
        emit(error: error)
        destroy()
    }
  }
  

  private func close() {
    guard let fileHandle = fileHandle else { return }
    do {
      try fileHandle.close()
      self.fileHandle = nil
      closeListeners.emit()
      closeListeners.removeAll()
      _clearListeners()
    }
    catch {
      emit(error: error)
    }
  }

  private func flushBuffer() {
    guard state != .pending && !writableBuffer.isEmpty else { return }
    
    let buffer = writableBuffer; writableBuffer = []
    if state == .destroyed {
      for ( _, whenDone ) in buffer { whenDone() }
    }
    else {
      for ( bytes, whenDone ) in buffer {
        _ = _write(bytes, whenDone: whenDone)
      }
    }
  }
  
  // MARK: - Listeners
  
  override open func _clearListeners() {
    _clearFileListeners()
    super._clearListeners()
  }

  public var readyListeners = EventListenerSet<Void>()
  public var closeListeners = EventListenerSet<Void>()
  public var openListeners  = EventListenerSet<NIOFileHandle>()
}
