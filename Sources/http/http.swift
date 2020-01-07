//
//  http.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
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

/// Creates an `http.Server` object and attaches a provided `onRequest` handler.
///
/// To activate the server, the `listen` method needs to be called.
///
/// Example:
///
///     http.createServer { req, res in
///       res.end("Hello World!")
///     }
///     .listen(1337)
///
@inlinable
@discardableResult
func createServer(handler: (( IncomingMessage, ServerResponse ) -> Void)? = nil)
     -> Server
{
  let server = Server()
  if let handler = handler { _ = server.onRequest(execute: handler) }
  return server
}
