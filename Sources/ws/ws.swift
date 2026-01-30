//
//  ws.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

@_exported import enum  MacroCore.EventListenerSet
@_exported import class MacroCore.ErrorEmitter
@_exported import func  MacroCore.nextTick
@_exported import class http.Server
@_exported import class http.IncomingMessage
@_exported import class http.ServerResponse

/**
 * The Macro WebSocket module.
 *
 * This module provides WebSocket support following the Node.js
 * [ws](https://github.com/websockets/ws) library patterns.
 *
 * ### Server Example
 *
 * ```swift
 * import ws
 *
 * let wss = WebSocket.Server(port: 8080)
 * wss.onConnection { ws in
 *   ws.onMessage { message in
 *     console.log("Received:", message)
 *   }
 *   ws.send("Hello!")
 * }
 * ```
 *
 * ### Client Example
 *
 * ```swift
 * import ws
 *
 * let ws = WebSocket("ws://localhost:8080/")
 * ws.onOpen { ws in
 *   ws.send("Hello Server!")
 * }
 * ws.onMessage { message in
 *   console.log("Received:", message)
 * }
 * ```
 */
public enum WSModule {}

public extension WSModule {
  typealias WebSocket = ws.WebSocket
  typealias Server    = ws.WebSocket.Server
}
