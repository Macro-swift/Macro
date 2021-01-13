//
//  Server.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import enum      MacroCore.EventListenerSet
import class     http.Server
import typealias NIOHTTP1.NIOHTTPServerUpgradeConfiguration
import protocol  NIOHTTP1.HTTPServerProtocolUpgrader

// during development:
import NIO
import NIOHTTP1
import NIOWebSocket

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
    
    // TODO: implement me
    // TODO: `ws` supports creation w/ an `http.Server` object
    // - presumably this works w/ the `upgrade` functionality?
    
    private var _connectionListeners = EventListenerSet<( WebSocket )>()
    
    @discardableResult
    public func onConnection(execute: @escaping ( WebSocket ) -> Void) -> Self {
      lock.lock()
      _connectionListeners.add(execute)
      lock.unlock()
      return self
    }

    lazy var upgrader : HTTPServerProtocolUpgrader = {
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
        return channel.pipeline
          .removeHandler(name: http.Server.httpHandlerName)
          .flatMap { ( _ ) -> EventLoopFuture<Void> in
            let ws      = WebSocket(channel)
            let handler = WebSocketConnection(ws)
            return channel.pipeline
              .addHandler(handler, name: Server.webSocketHandlerName)
          }
      }
    
      return NIOWebSocketServerUpgrader(shouldUpgrade: shouldUpgrade,
                                        upgradePipelineHandler: upgradeHandler)
    }()

    private var combinedUpgradeConfiguration :
                  NIOHTTPServerUpgradeConfiguration?

    #if false // TODO
    override open var upgradeConfiguration : NIOHTTPServerUpgradeConfiguration?{
      set {
        
      }
      get {
        
      }
    }
    #endif
    
    private static let webSocketHandlerName = "μ.ws.server.handler"
    
    private class WebSocketConnection: ChannelInboundHandler {
      
      public typealias InboundIn   = WebSocketFrame
      public typealias OutboundOut = WebSocketFrame
      
      let ws : WebSocket
      private var awaitingClose = false
      
      init(_ ws: WebSocket) {
        self.ws = ws
      }
      
      open func handlerRemoved(context: ChannelHandlerContext) {
        // tell `WebSocket` to shut down?
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
