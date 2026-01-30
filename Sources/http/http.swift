//
//  http.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2025 ZeeZide GmbH. All rights reserved.
//

/**
 * The Macro HTTP module.
 */
public enum HTTPModule {
}

public extension HTTPModule {
  
  typealias IncomingMessage = http.IncomingMessage
  typealias ServerResponse  = http.ServerResponse
  typealias Server          = http.Server

  /** 
   * Creates an `http.Server` (``Server`` object and attaches a provided 
   * ``Server/onRequest(execute:)`` handler.
   *
   * To activate the server, a ``Server/listen(_:_:backlog:onListening:)``
   * method needs to be called.
   *
   * Example:
   * ```swift
   * http.createServer { req, res in
   *   res.end("Hello World!")
   * }
   * .listen(1337)
   * ```
   */
  @inlinable
  @discardableResult
  static func createServer(handler: (( IncomingMessage, ServerResponse )
                                       -> Void)? = nil)
              -> Server
  {
    return http.createServer(handler: handler)
  }
}


// MARK: - Server

/** 
 * Creates an `http.Server` (``Server`` object and attaches a provided 
 * ``Server/onRequest(execute:)`` handler.
 *
 * To activate the server, a ``Server/listen(_:_:backlog:onListening:)``
 * method needs to be called.
 *
 * Example:
 * ```swift
 * http.createServer { req, res in
 *   res.end("Hello World!")
 * }
 * .listen(1337)
 * ```
 */
@inlinable
@discardableResult
public func createServer(handler: (( IncomingMessage, ServerResponse ) -> Void)?
                         = nil)
            -> Server
{
  let server = Server()
  if let handler = handler { _ = server.onRequest(execute: handler) }
  return server
}
