//
//  WebSocketConnection.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   NIO.ByteBuffer
import struct   NIO.NIOAny
import protocol NIO.ChannelInboundHandler
import class    NIO.ChannelHandlerContext
import struct   NIOWebSocket.WebSocketFrame

final class WebSocketConnection: ChannelInboundHandler {
  
  public typealias InboundIn   = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame
  
  let ws : WebSocket
  private var awaitingClose = false
  
  init(_ ws: WebSocket) {
    self.ws = ws
  }
  
  func handlerAdded(context: ChannelHandlerContext) {
    ws.emitOpen()
  }
  
  func channelActive(context: ChannelHandlerContext) {
  }
  
  /// Process WebSocket frames.
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
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
