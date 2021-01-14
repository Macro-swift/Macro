//
//  URLSessionClientRequest.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   MacroCore.Buffer
import enum     MacroCore.WritableError
import struct   Foundation.URL
import class    Foundation.NSObject
import struct   Logging.Logger
import protocol NIO.EventLoop
import struct   NIOHTTP1.HTTPResponseHead
import enum     NIOHTTP1.HTTPResponseStatus
import struct   NIOHTTP1.HTTPHeaders

#if canImport(FoundationNetworking)
  import class    FoundationNetworking.URLSession
  import struct   FoundationNetworking.URLRequest
  import class    FoundationNetworking.URLSessionTask
  import class    FoundationNetworking.URLSessionDataTask
  import class    FoundationNetworking.HTTPURLResponse
#else
  import class    Foundation.URLSession
  import struct   Foundation.URLRequest
  import class    Foundation.URLSessionTask
  import class    Foundation.URLSessionDataTask
  import class    Foundation.HTTPURLResponse
#endif

public final class URLSessionClientRequest: ClientRequest {
  
  let agent           : URLSessionAgent
  let request         : URLRequest
  let eventLoop       : EventLoop
  var task            : URLSessionDataTask?
  var isWaitingForEnd = false
  var writtenContent  = Buffer()

  var response        : IncomingMessage?

  private var didRetain = false

  init(agent: URLSessionAgent, request: URLRequest, eventLoop: EventLoop) {
    self.agent     = agent
    self.request   = request
    self.eventLoop = eventLoop

    super.init(unsafeChannel: nil, log: agent.options.logger)
  }
  deinit {
    if didRetain { core.release(); didRetain = false }
  }

  private var selfRef : AnyObject?
  
  private func setupResponse(with httpResponse: HTTPURLResponse?)
               -> IncomingMessage
  {
    assert(response == nil)
    
    var headers = HTTPHeaders()
    for ( name, value ) in httpResponse?.allHeaderFields ?? [:] {
      if let name = name as? String, let value = value as? String {
        headers.add(name: name, value: value)
      }
      else {
        headers.add(name: String(describing: name),
                    value: String(describing: value)) // TBD
      }
    }
    let status = HTTPResponseStatus(statusCode: httpResponse?.statusCode ?? 200)
    
    let response = IncomingMessage(status: status, headers: headers)
    return response
  }
  
  func startRequest() {
    assert(task == nil)
    assert(response == nil)
    
    let eventLoop = self.eventLoop
    
    var request = self.request
    if !writtenContent.isEmpty {
      request.httpBody = writtenContent.data
    }
        
    // FIXME: the agent should be the session delegate and do the receiving
    task = agent.options.session.dataTask(with: request) {
      data, urlResponse, error in
      defer { self.task = nil }
      
      let response = self.setupResponse(with: urlResponse as? HTTPURLResponse)
      self.response = response
      
      eventLoop.execute {
        self.responseListeners.emit(response)
      }
      
      // give the client another chance to register in a delayed way!
      eventLoop.execute {
        if let data = data, !data.isEmpty {
          response.push(Buffer(data))
        }
        response.push(nil) // EOF
        
        self.selfRef = nil
        if self.didRetain { self.didRetain = false; self.core.release() }
      }
    }

    guard let task = task else {
      log.error("request has no associated data task!")
      assertionFailure("attempt to start request w/o data task!")
      return
    }
    
    if !didRetain { didRetain = true; core.retain() }
    selfRef = self
    task.resume()
  }
  
  
  // MARK: - Writable stream ...

  override public func end() {
    guard !writableEnded else { return }

    finishListeners.emit()
    _clearListenersOnFinish()
    
    if isWaitingForEnd {
      isWaitingForEnd = false
      startRequest()
    }
  }
  private func _clearListenersOnFinish() {
    finishListeners.removeAll()
    errorListeners .removeAll()
  }

  @discardableResult
  public override func write(_ bytes: Buffer,
                             whenDone: @escaping () -> Void) -> Bool {
    writtenContent.append(bytes)
    whenDone()
    return true
  }
  @discardableResult @inlinable
  override public func write(_ string: String,
                             whenDone: @escaping () -> Void = {}) -> Bool
  {
    return write(Buffer(string), whenDone: whenDone)
  }
}
