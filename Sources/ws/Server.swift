//
//  Server.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct    Logging.Logger
import enum      MacroCore.EventListenerSet
import func      MacroCore.nextTick
import class     http.Server
import typealias NIOHTTP1.NIOHTTPServerUpgradeConfiguration
import protocol  NIOHTTP1.HTTPServerProtocolUpgrader
import struct    NIOHTTP1.HTTPHeaders
import struct    NIOHTTP1.HTTPRequestHead
import protocol  NIO.Channel
import class     NIO.EventLoopFuture
import class     NIOWebSocket.NIOWebSocketServerUpgrader

extension WebSocket {
  
  /**
   * A WebSocket Server instance.
   *
   * Example:
   *
   *     import ws
   *     
   *     let wss = WebSocket.Server(port: 8080)
   *     wss.onConnection { ws in
   *       ws.onMessage { message in
   *         console.log("Received:", message)
   *       }
   *
   *       ws.send("Hello!")
   *     }
   */
  open class Server: http.Server {
    // This is going to be a little different to Node, this directly hooks up
    // with NIO.
    // In Node the server also has 'upgrade' things, which we do not yet support
    // in Macro.

    /**
     * Initialize _and_ start a WebSocket server.
     *
     * The server is started in the next tick, listeners can still be setup
     * after calling this initializer.
     *
     * Example:
     *
     *     let wss = WebSocket.Server(port: 8080)
     *
     * The server rejects all HTTP requests.
     */
    public init(port: Int, log: Logger = .init(label: "μ.ws")) {
      super.init(log: log)
      
      onRequest { req, res in
        log.error("WebSocket server got HTTP request:", req)
        res.writeHead(403)
        res.end()
      }
      
      nextTick {
        self.listen(port)
      }
    }

    private var _connectionListeners = EventListenerSet<( WebSocket )>()
    
    @discardableResult
    public func onConnection(execute: @escaping ( WebSocket ) -> Void) -> Self {
      lock.lock()
      _connectionListeners.add(execute)
      lock.unlock()
      return self
    }

    private lazy var upgrader : HTTPServerProtocolUpgrader = {
      func shouldUpgrade(channel: Channel, head: HTTPRequestHead)
           -> EventLoopFuture<HTTPHeaders?>
      {
        let promise = channel.eventLoop.makePromise(of: HTTPHeaders?.self)
        promise.succeed(HTTPHeaders())
        return promise.futureResult
      }
    
      func upgradeHandler(channel: Channel, head: HTTPRequestHead)
           -> EventLoopFuture<Void>
      {
        let log     = self.log
        let ws      = WebSocket(channel)
        let handler = WebSocketConnection(ws)
        
        guard !_connectionListeners.isEmpty else {
          struct NoListenersError: Swift.Error {}
          let promise = channel.eventLoop.makePromise(of: Void.self)
          promise.fail(NoListenersError())
          return promise.futureResult
        }
        
        return channel.pipeline
          .removeHandler(name: http.Server.httpHandlerName)
          .flatMap { ( _ ) -> EventLoopFuture<Void> in
            return channel.pipeline
                     .addHandler(handler, name: Server.webSocketHandlerName)
          }
          .map {
            if self._connectionListeners.isEmpty {
              log.error("no WebSocket connection listeners:", self)
              assertionFailure("connection listeners modified during upgrade")
              channel.close(mode: .all, promise: nil)
            }
            else {
              self._connectionListeners.emit(ws)
            }
          }
      }
    
      return NIOWebSocketServerUpgrader(shouldUpgrade: shouldUpgrade,
                                        upgradePipelineHandler: upgradeHandler)
    }()
    
    private var combinedUpgradeConfiguration :
                  NIOHTTPServerUpgradeConfiguration?
    
    override open var upgradeConfiguration : NIOHTTPServerUpgradeConfiguration?
    {
      set {
        if listening {
          log.warn("Setting new upgrade config,",
                   "but server is already listening!")
        }
        
        guard let newValue = newValue else {
          combinedUpgradeConfiguration = nil
          return
        }
        if newValue.upgraders
            .contains(where: { $0 is NIOWebSocketServerUpgrader })
        {
          combinedUpgradeConfiguration = newValue
        }
        else {
          combinedUpgradeConfiguration = (
            upgraders: newValue.upgraders + [ upgrader ],
            completionHandler: newValue.completionHandler
          )
        }
      }
      get {
        return combinedUpgradeConfiguration ?? (
          upgraders: [ upgrader ],
          completionHandler: { _ in }
        )
      }
    }
    
    private static let webSocketHandlerName = "μ.ws.server.handler"    
  }
}
