//
//  ServerResponse.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import protocol NIO.Channel
import struct   NIOHTTP1.HTTPHeaders
import enum     NIOHTTP1.HTTPResponseStatus
import struct   NIOHTTP1.HTTPResponseHead
import struct   NIOHTTP1.HTTPVersion
import enum     NIOHTTP1.HTTPServerResponsePart
import struct   Logging.Logger
import enum     MacroCore.WritableError
import struct   MacroCore.Buffer

/**
 * An object representing the response an HTTP server sends out to the client.
 * It is created by the `http.Server` object when an HTTP transaction is
 * started.
 *
 * This is a `WritableByteStream`.
 *
 * Example:
 *
 *     app.use { req, res, next in
 *       res.writeHead(200, [ "Content-Type": "text/html" ])
 *       res.write("<h1>Hello Client: \(req.url)</h1>")
 *       res.end()
 *     }
 * 
 * Make sure to call `end` to close the connection properly.
 *
 * Hierarchy:
 *
 *   WritableStreamBase
 *     WritableByteStreamBase
 *       OutgoingMessage
 *       * ServerResponse
 *         ClientRequest
 */
open class ServerResponse: OutgoingMessage, CustomStringConvertible {

  public var version = HTTPVersion(major: 1, minor: 1)
  public var status  = HTTPResponseStatus.ok

  override open var writableCorked : Bool { return corkCount > 0 }
  private var corkCount      = 0
  open    var writableBuffer : Buffer?

  public convenience init(channel: Channel,
                          log: Logger = .init(label: "μ.http"))
  {
    self.init(unsafeChannel: channel, log: log)
  }
  override public init(unsafeChannel channel: Channel?, log: Logger) {
    super.init(unsafeChannel: channel, log: log)
  }
  
  
  // MARK: - Corking
  
  open func cork() {
    corkCount += 1
  }
  open func uncork() {
    corkCount -= 1
    if !writableCorked { flush() }
  }
  
  private func flush() {
    let wasEnding = state == .isEnding
    if let buffer = writableBuffer {
      writableBuffer = nil
      write(buffer)
    }
    if wasEnding {
      state = .ready // otherwise 'end' won't run
      end()
    }
  }

  
  // MARK: - Emit Header
  
  @usableFromInline
  internal func primaryWriteHead(_ part: HTTPResponseHead) {
    assert(!headersSent)
    guard !headersSent else { return }
    headersSent = true
    
    if let channel = socket {
      channel.writeAndFlush(HTTPServerResponsePart.head(part))
             .whenFailure(handleError)
    }
    else {
      version = part.version
      status  = part.status
      headers = part.headers
    }
  }
  @usableFromInline
  internal func primaryWriteHead() {
    let head = HTTPResponseHead(version: version,
                                status: status, headers: headers)
    primaryWriteHead(head)
  }

  @inlinable
  open func writeHead(_ status: HTTPResponseStatus = .ok,
                      headers: HTTPHeaders = [:])
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
  
  public var trailers : NIOHTTP1.HTTPHeaders?
  
  open func addTrailers(_ trailers: NIOHTTP1.HTTPHeaders) {
    if self.trailers == nil { self.trailers = trailers }
    else { self.trailers?.add(contentsOf: trailers) }
  }
  
  override open func end() {
    guard !writableEnded else { return }
    if !headersSent { primaryWriteHead() }
    
    if writableCorked {
      corkCount = 0
    }

    if let channel = socket {
      state = .isEnding
      if writableBuffer != nil {
        return flush() // this will recurse
      }
      channel.writeAndFlush(HTTPServerResponsePart.end(nil))
             .whenComplete { result in
               if case .failure(let error) = result {
                 self.handleError(error)
               }
               self.state = .finished
               self.finishListeners.emit()
               self._clearListenersOnFinish()
             }
    }
    else {
      state = .finished
      finishListeners.emit()
      _clearListenersOnFinish()
    }
  }
  private func _clearListenersOnFinish() {
    finishListeners.removeAll()
    errorListeners .removeAll()
  }
  
  
  // MARK: - Node like API
  
  @inlinable
  public var statusCode : Int {
    set { status = HTTPResponseStatus(statusCode: newValue) }
    get { return Int(status.code) }
  }
  
  /**
   * Set the HTTP response status message.
   * Careful: Needs to be called after setting the `statusCode`.
   */
  @inlinable
  public var statusMessage : String {
    set { status = HTTPResponseStatus(statusCode   : statusCode,
                                      reasonPhrase : newValue) }
    get { return status.reasonPhrase }
  }
  
  @inlinable
  open func writeHead(_ statusCode: Int,
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
  @inlinable
  public func writeHead(_ statusCode : Int,
                        _ headers    : [ String : Any ] = [ : ])
  {
    writeHead(statusCode, nil, headers)
  }
  
  
  // MARK: - 100-continue
  
  open func writeContinue() {
    guard !writableEnded else {
      handleError(WritableError.writableEnded)
      return
    }
    
    // TODO: what about corking here? We should probably remember that
    
    guard let channel = socket else {
      if !writableCorked { // allow this in cork mode
        handleError(WritableError.writableEnded)
      }
      return
    }
    
    let head = HTTPResponseHead(version: version, status: .continue)
    channel.writeAndFlush(HTTPServerResponsePart.head(head))
           .whenFailure(handleError)
  }

  
  // MARK: - WritableByteStream
  
  @discardableResult
  open func write(_ bytes: Buffer, whenDone: @escaping ( Error? ) -> Void)
            -> Bool
  {
    guard !writableEnded else {
      handleError(WritableError.writableEnded)
      return true
    }
    
    if !headersSent { primaryWriteHead() }
    
    if writableCorked {
      // TBD: would probably better to couple the whenDone with the buffers?
      if writableBuffer != nil { writableBuffer?.append(bytes) }
      else                     { writableBuffer = bytes        }
      whenDone(nil)
      return (writableBuffer?.count ?? 0) < writableHighWaterMark
    }
    
    guard let channel = socket else {
      handleError(WritableError.writableEnded)
      whenDone(WritableError.writableEnded)
      return false
    }
    
    channel.writeAndFlush(HTTPServerResponsePart
                            .body(.byteBuffer(bytes.byteBuffer)))
           .whenComplete { result in
             if case .failure(let error) = result {
               self.handleError(error)
               whenDone(error)
             }
             else {
               whenDone(nil)
             }
           }
    return true
  }
  
  @discardableResult
  override open func write(_ bytes: Buffer,
                           whenDone: @escaping () -> Void = {}) -> Bool
  {
    return write(bytes) { _ in whenDone() }
  }

  // MARK: - CustomStringConvertible

  open var description: String {
    let id = "0x" + String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    var ms = "<ServerResponse[\(id)]:"
    defer { ms += ">" }

    if writableCorked {
      if let count = writableBuffer?.count, count > 0 {
        ms += " corked=#\(count)"
      }
      else {
        ms += " corked(empty)"
      }
    }
    else {
      if socket == nil { ms += " no-socket" }
      if let count = writableBuffer?.count, count > 0 {
        ms += " buffer=#\(count)"
      }
    }
    
    ms += " \(statusCode)"
    if writableEnded  { ms += " ended"  }
    
    if !environment.isEmpty {
      ms += "\n"
      for ( key, value ) in environment.loggingDictionary {
        ms += "  \(key)=\(value)\n"
      }
    }

    return ms
  }
}
