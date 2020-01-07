//
//  FileReadStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class    MacroCore.MacroCore
import class    MacroCore.ReadableByteStream
import enum     MacroCore.EventListenerSet
import class    NIO.NIOFileHandle
import protocol NIO.EventLoop
import struct   NIO.NonBlockingFileIO

@inlinable
public func createReadStream(on eventLoop: EventLoop? = nil,
                             _ path: String) -> FileReadStream
{
  let core = MacroCore.shared
  return FileReadStream(eventLoop: core.fallbackEventLoop(eventLoop),
                        path: path)
}

open class FileReadStream: ReadableByteStream, FileStream {

  public static var defaultReadableHighWaterMark = 64 * 1024
  
  public let eventLoop  : EventLoop
  public let path       : String
  public var fileHandle : NIOFileHandle?
  public var pending    = true

  override open var readableFlowing : Bool {
    didSet {
      // TBD: I think `flowing` refers to `data` vs `readable` events, not
      //      whether the connection is paused. Read up on that :-)
      guard oldValue != readableFlowing else { return }
      if readableFlowing {
        _resume()
      }
    }
  }

  @inlinable
  init(eventLoop: EventLoop, path: String) {
    self.eventLoop = eventLoop
    self.path      = path
    super.init()
    readableHighWaterMark = FileReadStream.defaultReadableHighWaterMark
  }
  
  public func _resume() {
    assert(readableFlowing)
    
    if pending {
      open()
    }
    else {
      if !readableFlowing { readableFlowing = true }
      startReading()
    }
  }
  
  private func close() {
    readableFlowing = false
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
  
  private func handleEOF() {
    endListeners.emit()
    endListeners.removeAll()
    
    readableFlowing = false
    close()
  }
  
  private func startReading() {
    assert(!pending)
    guard let fileHandle = fileHandle else {
      assert(self.fileHandle != nil)
      return
    }
    
    // Note: Right now we just read proactively regardless of the HWM.
    #if false // FIXME: once we can properly do this
      let bytesToRead = readableHighWaterMark - readableLength
    #else
      let space = readableHighWaterMark - readableLength
      let bytesToRead = space > 0 ? space : readableHighWaterMark
    #endif
    
    fileIO.read(fileHandle: fileHandle, byteCount: bytesToRead,
                allocator: allocator, eventLoop: eventLoop)
      .whenComplete { result in
        switch result {
          case .success(let buffer):
            if buffer.readableBytes == 0 {
              self.handleEOF()
            }
            else {
              self.push(buffer)
              self.startReading() // not actually recursive ...
            }
          case .failure(let error):
            self.emit(error: error)
        }
      }
  }
  
  private func open() {
    assert(fileHandle == nil)
    assert(pending)
    fileIO.openFile(path: path, mode: .read, eventLoop: eventLoop)
          .whenComplete(_handleOpenResult)
  }
  func _handleOpenResult(_ result: Result<NIOFileHandle, Swift.Error>) {
    switch result {
      case .success(let handle):
        assert(self.fileHandle == nil, "file handle already assigned!")
        try? self.fileHandle?.close()
        
        fileHandle = handle
        pending    = false
        openListeners .emit(handle)
        readyListeners.emit()
        openListeners .removeAll()
        readyListeners.removeAll()
        _resume()
      
      case .failure(let error):
        pending    = false
        emit(error: error)
        endListeners.emit()
        _clearListeners()
    }
  }
  

  override open func _clearListeners() {
    _clearFileListeners()
    super._clearListeners()
  }
  
  public var readyListeners = EventListenerSet<Void>()
  public var closeListeners = EventListenerSet<Void>()
  public var openListeners  = EventListenerSet<NIOFileHandle>()  
}
