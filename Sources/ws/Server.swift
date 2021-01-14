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
import struct    NIO.ByteBuffer
import struct    NIO.NIOAny
import protocol  NIO.Channel
import protocol  NIO.ChannelInboundHandler
import class     NIO.ChannelHandlerContext
import class     NIO.EventLoopFuture
import struct    NIOWebSocket.WebSocketFrame
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

        return channel.pipeline
          .removeHandler(name: http.Server.httpHandlerName)
          .flatMap { ( _ ) -> EventLoopFuture<Void> in
            return channel.pipeline
                     .addHandler(handler, name: Server.webSocketHandlerName)
          }
          .map {
            if self._connectionListeners.isEmpty {
              log.error("no WebSocket connection listeners:", self)
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
    
    private class WebSocketConnection: ChannelInboundHandler {
      
      public typealias InboundIn   = WebSocketFrame
      public typealias OutboundOut = WebSocketFrame
      
      let ws : WebSocket
      private var awaitingClose = false
      
      init(_ ws: WebSocket) {
        self.ws = ws
      }
      
      /// Process WebSocket frames.
      open func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        
        switch frame.opcode {
          case .connectionClose:
            self.receivedClose(in: context, frame: frame)
          
          case .ping:
            self.pong(in: context, frame: frame)
          
          case .continuation:
            // TBD: what do we need to do here?
            ws.log.error("Received continuation?")
          
          case .text:
            handleInput(frame.unmaskedData, in: context)
          
          case .binary:
            handleInput(frame.unmaskedData, in: context)
            
          case .pong:
            ws.emitPong()
          
          default:
            self.closeOnError(in: context)
        }
      }

      private func handleInput(_ bb: ByteBuffer,
                               in context: ChannelHandlerContext)
      {
        let data = bb.getData(at: bb.readerIndex, length: bb.readableBytes)!
        ws.processIncomingData(data)
      }
      
      private func pong(in context: ChannelHandlerContext, frame: WebSocketFrame) {
        var frameData  = frame.data
        let maskingKey = frame.maskKey
        
        if let maskingKey = maskingKey {
          frameData.webSocketUnmask(maskingKey)
        }
        
        let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
        context.write(self.wrapOutboundOut(responseFrame), promise: nil)
      }
      
      private func closeOnError(in context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close
        // frame and then shutting down the write side of the connection.
        var data = context.channel.allocator.buffer(capacity: 2)
        data.write(webSocketErrorCode: .protocolError)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose,
                                   data: data)
        _ = context.write(self.wrapOutboundOut(frame)).flatMap {
          context.close(mode: .output)
        }
        awaitingClose = true
      }

      private func receivedClose(in context: ChannelHandlerContext,
                                 frame: WebSocketFrame)
      {
        if awaitingClose {
          return context.close(promise: nil)
        }
        
        var data          = frame.unmaskedData
        let closeDataCode = data.readSlice(length: 2)
                         ?? context.channel.allocator.buffer(capacity: 0)
        let closeFrame    = WebSocketFrame(fin: true, opcode: .connectionClose,
                                           data: closeDataCode)
        _ = context.write(wrapOutboundOut(closeFrame)).map { () in
          context.close(promise: nil)
        }
      }
    }
  }
}
