//
//  ReadableByteStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * A `Buffer` based stream. This buffers the data until it is read.
 */
open class ReadableByteStream: ReadableStreamBase<Buffer>,
                               ReadableStreamType,
                               ReadableByteStreamType
{
  
  public var readableBuffer : Buffer?
  
  @inlinable
  override open var readableLength : Int { return readableBuffer?.count ?? 0 }

  /// This is used to coalesce multiple reads. Do not trigger readable, if we
  /// sent readable already, but the client didn't call `read()` yet.
  @usableFromInline internal var readPending = false
  
  public func push(_ bytes: Buffer) {
    guard !readableEnded else {
      assert(!readableEnded, "trying to push to a readable which ended!")
      emit(error: ReadableError.readableEnded)
      return
    }
    
    // TBD: was push <empty> the same like EOF/end?
    guard bytes.count > 0 else { return }
    
    // when in reading mode, `data` is only emitted when `read` is called
    if readableListeners.isEmpty && !dataListeners.isEmpty {
      dataListeners.emit(bytes)
      return // pure 'data' mode, do not buffer
    }
    
    if readableBuffer == nil { readableBuffer = bytes }
    else { readableBuffer?.append(bytes) }
    
    if !readPending && !readableListeners.isEmpty {
      readPending = true
      readableListeners.emit()
    }
  }
  
  public func read(_ count: Int? = nil) -> Buffer {
    readPending = false
    guard let buffer = readableBuffer else { return core.emptyBuffer }
    
    let readBuffer : Buffer
    if let count = count, count < buffer.count {
      guard count > 0 else { return core.emptyBuffer }
      readBuffer = self.readableBuffer!.consumeFirst(count)
    }
    else {
      readBuffer = buffer
      self.readableBuffer = nil
    }
    dataListeners.emit(readBuffer)
    return readBuffer
  }
  
  
  @usableFromInline
  internal func _emitDataIfAppropriate(execute: ( Buffer ) -> Void) -> Bool
  {
    guard let buffer = self.readableBuffer, !buffer.isEmpty else {
      return false
    }
    if readableListeners.isEmpty {
      self.readableBuffer = nil
      execute(buffer)
      return true
    }
    else if !readPending {
      execute(buffer)
      return true
    }
    // else: will be triggered on next read
    return false
  }

  @discardableResult
  @inlinable
  open func onceData(execute: @escaping ( Buffer ) -> Void) -> Self {
    if !_emitDataIfAppropriate(execute: execute) {
      dataListeners.once(execute)
      readableFlowing = true
    }
    return self
  }
  
  @discardableResult
  @inlinable
  open func onData(execute: @escaping ( Buffer ) -> Void) -> Self {
    dataListeners.add(execute)
    readableFlowing = true
    _ = _emitDataIfAppropriate(execute: execute)
    return self
  }

  open func _clearListeners() {
    dataListeners    .removeAll()
    readableListeners.removeAll()
    errorListeners   .removeAll()
    endListeners     .removeAll()
  }
}
