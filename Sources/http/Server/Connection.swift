//
//  Connection.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (c) 2020-2026 ZeeZide GmbH. All rights reserved.
//

import NIOCore

extension Server {

  /**
   * Represents a TCP connection accepted by the HTTP server.
   *
   * Passed to the ``Server/onConnection(execute:)`` callback
   * when a new client connects. Mirrors the Node.js
   * `net.Socket` API for the most common properties.
   *
   * ```swift
   * server.onConnection { connection in
   *   print("New connection from",
   *         connection.remoteAddress ?? "unknown")
   * }
   * ```
   */
  public struct Connection: Sendable {

    @usableFromInline
    let channel : NIOCore.Channel

    init(_ channel: NIOCore.Channel) {
      self.channel = channel
    }

    /// Remote IP address (e.g. `"127.0.0.1"`).
    @inlinable
    public var remoteAddress : String? {
      channel.remoteAddress?.ipAddress
    }

    /// Remote TCP port.
    @inlinable
    public var remotePort : Int? {
      channel.remoteAddress?.port
    }

    /// Local IP address the connection was accepted on.
    @inlinable
    public var localAddress : String? {
      channel.localAddress?.ipAddress
    }

    /// Local TCP port the connection was accepted on.
    @inlinable
    public var localPort : Int? {
      channel.localAddress?.port
    }

    /// Close the connection.
    public func destroy() {
      channel.close(mode: .all, promise: nil)
    }
  }
}
