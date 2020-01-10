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
 */
open class ServerResponse: OutgoingMessage {

  public var version = HTTPVersion(major: 1, minor: 1)
  public var status  = HTTPResponseStatus.ok

  override public init(channel: Channel,
                       log: Logger = .init(label: "μ.http"))
  {
    super.init(channel: channel, log: log)
  }
  
  
  // MARK: - Emit Header
  
  @usableFromInline
  internal func primaryWriteHead(_ part: HTTPResponseHead) {
    assert(!headersSent)
    guard !headersSent else { return }
    headersSent = true
    socket?.writeAndFlush(HTTPServerResponsePart.head(part))
           .whenFailure(handleError)
  }
  @usableFromInline
  internal func primaryWriteHead() {
    let head = HTTPResponseHead(version: version,
                                status: status, headers: headers)
    primaryWriteHead(head)
  }

  @inlinable
  public func writeHead(_ status: HTTPResponseStatus = .ok,
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
  
  public func addTrailers(_ trailers: NIOHTTP1.HTTPHeaders) {
    if self.trailers == nil { self.trailers = trailers }
    else { self.trailers?.add(contentsOf: trailers) }
  }
  
  override open func end() {
    guard !writableEnded else { return }
    
    
    if let channel = socket {
      state = .isEnding
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
  public func writeHead(_ statusCode: Int,
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
  
  public func writeContinue() {
    guard !writableEnded else {
      handleError(WritableError.writableEnded)
      return
    }
    guard let channel = socket else {
      handleError(WritableError.writableEnded)
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
}
