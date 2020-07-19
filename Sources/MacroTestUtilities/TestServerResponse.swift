//
//  TestServerResponse.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Logging.Logger
import struct NIOHTTP1.HTTPHeaders
import enum   NIOHTTP1.HTTPResponseStatus
import struct NIOHTTP1.HTTPResponseHead
import enum   MacroCore.WritableError
import struct MacroCore.Buffer
import class  http.ServerResponse

public let MacroTestLogger = Logger(label: "μ.tests")

/**
 * A ServerResponse for testing purposes. Doesn't write to an actual Channel.
 */
open class TestServerResponse: ServerResponse {
  
  public var continueCount  = 0
  public var writtenContent = Buffer()
  public var errorToTrigger : Swift.Error?

  public init() {
    super.init(unsafeChannel: nil, log: MacroTestLogger)
  }
  
  
  // MARK: - Emit Header
  
  @usableFromInline
  internal func primaryWriteHead(_ part: HTTPResponseHead) {
    assert(!headersSent)
    guard !headersSent else { return }
    headersSent = true
  }
  @usableFromInline
  internal func primaryWriteHead() {
    let head = HTTPResponseHead(version: version,
                                status: status, headers: headers)
    primaryWriteHead(head)
  }
  
  @inlinable
  override public func writeHead(_ status : HTTPResponseStatus = .ok,
                                 headers  : HTTPHeaders = [:])
  {
    if !headers.isEmpty {
      for ( name, value ) in headers {
        setHeader(name, value)
      }
    }
    let head = HTTPResponseHead(version: version,
                                status: status, headers: headers)
    primaryWriteHead(head)
  }
  
  
  // MARK: - End
  
  override open func end() {
    guard !writableEnded else { return }
    if !headersSent { primaryWriteHead() }

    state = .finished
    finishListeners.emit()
    _clearListenersOnFinish()
  }
  private func _clearListenersOnFinish() {
    finishListeners.removeAll()
    errorListeners .removeAll()
  }
  
  
  @inlinable
  override open func writeHead(_    statusCode : Int,
                               _ statusMessage : String?,
                               _ headers       : [ String : Any ] = [ : ])
  {
    assert(!headersSent)
    guard !headersSent else { return }
    
    self.statusCode = statusCode
    if let s = statusMessage { self.statusMessage = s }
     
    // merge in headers
    for ( key, value ) in headers {
      setHeader(key, value)
    }
    
    primaryWriteHead()
  }
  
  
  // MARK: - 100-continue
  
  override open func writeContinue() {
    guard !writableEnded else {
      handleError(WritableError.writableEnded)
      return
    }

    continueCount += 1
  }

  
  // MARK: - WritableByteStream
  
  private func consumeErrorToTrigger() -> Swift.Error? {
    guard let error = errorToTrigger else { return nil }
    errorToTrigger = nil
    return error
  }
  
  @discardableResult
  override
  open func write(_ bytes: Buffer, whenDone: @escaping ( Error? ) -> Void)
            -> Bool
  {
    guard !writableEnded else {
      handleError(WritableError.writableEnded)
      return true
    }
    
    if !headersSent { primaryWriteHead() }
    
    if let error = consumeErrorToTrigger()  {
      handleError(error)
      whenDone(error)
    }
    else {
      writtenContent.append(bytes)
      whenDone(nil)
    }
    return true
  }
  
  @discardableResult
  override open func write(_ bytes: Buffer,
                           whenDone: @escaping () -> Void = {}) -> Bool
  {
    return write(bytes) { _ in whenDone() }
  }
  @discardableResult @inlinable override
  open func write(_ string: String, whenDone: @escaping () -> Void = {}) -> Bool
  {
    return write(Buffer(string), whenDone: whenDone)
  }


  // MARK: - CustomStringConvertible

  override open var description: String {
    var ms = "<TestResponse[\(ObjectIdentifier(self))]:"
    defer { ms += ">" }
    
    ms += " \(statusCode)"
    if writableEnded  { ms += " ended"  }
    if writableCorked { ms += " corked" }
    
    for ( key, value ) in extra { ms += " \(key)=\(value)" }
    
    if !writtenContent.isEmpty {
      ms += " #written=\(writtenContent.count)"
    }
    
    return ms
  }
}
