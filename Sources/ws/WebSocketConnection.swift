//
//  WebSocketConnection.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct   NIO.ByteBuffer
import struct   NIO.ByteBufferAllocator
import struct   NIO.NIOAny
import protocol NIO.ChannelInboundHandler
import class    NIO.ChannelHandlerContext
import struct   NIOWebSocket.WebSocketFrame
import struct   NIOWebSocket.WebSocketOpcode

final class WebSocketConnection: ChannelInboundHandler {
  
  public typealias InboundIn   = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame
  
  let ws : WebSocket
  private var awaitingClose    = false
  private var fragmentBuffer   : ByteBuffer?
  private var fragmentOpcode   : WebSocketOpcode?

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
        handleContinuation(context: context, frame: frame)

      case .text:
        handleTextFrame(context: context, frame: frame)

      case .binary:
        handleBinaryFrame(context: context, frame: frame)

      case .pong:
        ws.emitPong()
      
      default:
        self.closeOnError(in: context)
    }
  }

  // MARK: - Fragment Handling

  private func handleTextFrame(context: ChannelHandlerContext,
                               frame: WebSocketFrame)
  {
    if frame.fin {
      // Complete message in single frame
      if fragmentBuffer != nil {
        // Protocol error: received new text frame while fragment in progress
        closeOnError(in: context)
        return
      }
      handleTextInput(frame.unmaskedData)
    }
    else {
      // Start of fragmented message
      startFragment(opcode: .text, data: frame.unmaskedData,
                    allocator: context.channel.allocator)
    }
  }

  private func handleBinaryFrame(context: ChannelHandlerContext,
                                 frame: WebSocketFrame)
  {
    if frame.fin {
      // Complete message in single frame
      if fragmentBuffer != nil {
        // Protocol error: received new binary frame while fragment in progress
        closeOnError(in: context)
        return
      }
      handleBinaryInput(frame.unmaskedData)
    }
    else {
      // Start of fragmented message
      startFragment(opcode: .binary, data: frame.unmaskedData,
                    allocator: context.channel.allocator)
    }
  }

  private func handleContinuation(context: ChannelHandlerContext,
                                  frame: WebSocketFrame)
  {
    guard fragmentBuffer != nil, fragmentOpcode != nil else {
      // Protocol error: continuation without initial fragment
      closeOnError(in: context)
      return
    }

    appendToFragment(data: frame.unmaskedData)

    if frame.fin {
      // Final fragment - deliver complete message
      guard let buffer = finishFragment(), let opcode = fragmentOpcode else {
        return
      }
      fragmentOpcode = nil

      switch opcode {
        case .text   : handleTextInput(buffer)
        case .binary : handleBinaryInput(buffer)
        default      : break
      }
    }
  }

  private func startFragment(opcode: WebSocketOpcode, data: ByteBuffer,
                             allocator: ByteBufferAllocator)
  {
    var buffer = allocator.buffer(capacity: data.readableBytes)
    var mutableData = data
    buffer.writeBuffer(&mutableData)
    fragmentBuffer = buffer
    fragmentOpcode = opcode
  }

  private func appendToFragment(data: ByteBuffer) {
    var mutableData = data
    fragmentBuffer?.writeBuffer(&mutableData)
  }

  private func finishFragment() -> ByteBuffer? {
    let buffer = fragmentBuffer
    fragmentBuffer = nil
    return buffer
  }

  private func handleTextInput(_ bb: ByteBuffer) {
    guard let data = bb.getData(at: bb.readerIndex, length: bb.readableBytes)
    else { return }
    let text = bb.getString(at: bb.readerIndex, length: bb.readableBytes) ?? ""
    ws.processIncomingText(text, data: data)
  }

  private func handleBinaryInput(_ bb: ByteBuffer) {
    guard let data = bb.getData(at: bb.readerIndex, length: bb.readableBytes)
    else { return }
    ws.processIncomingBinary(data)
  }
  
  private func pong(in context: ChannelHandlerContext, frame: WebSocketFrame) {
    var frameData  = frame.data
    let maskingKey = frame.maskKey
    
    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }
    
    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
    context.writeAndFlush(self.wrapOutboundOut(responseFrame), promise: nil)
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
      context.close(promise: nil)
      ws.handleRemoteClose()
      return
    }
    
    var data          = frame.unmaskedData
    let closeDataCode = data.readSlice(length: 2)
                     ?? context.channel.allocator.buffer(capacity: 0)
    let closeFrame    = WebSocketFrame(fin: true, opcode: .connectionClose,
                                       data: closeDataCode)
    _ = context.write(wrapOutboundOut(closeFrame)).map { () in
      context.close(promise: nil)
      self.ws.handleRemoteClose()
    }
  }

  func channelInactive(context: ChannelHandlerContext) {
    fragmentBuffer = nil
    fragmentOpcode = nil
    ws.handleRemoteClose()
  }
}
