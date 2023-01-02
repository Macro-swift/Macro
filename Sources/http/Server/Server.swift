//
//  Server.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2022 ZeeZide GmbH. All rights reserved.
//

import class     MacroCore.ErrorEmitter
import enum      MacroCore.EventListenerSet
import class     MacroCore.MacroCore
import struct    MacroCore.Buffer
import struct    Logging.Logger
import struct    NIO.NIOAny
import class     NIO.EventLoopFuture
import class     NIO.ServerBootstrap
import protocol  NIO.Channel
import struct    NIO.ChannelOptions
import protocol  NIO.ChannelInboundHandler
import class     NIO.ChannelHandlerContext
import protocol  NIO.RemovableChannelHandler
import struct    NIO.SocketOptionLevel
import enum      NIO.SocketAddress
import let       NIO.SOL_SOCKET
import let       NIO.SO_REUSEADDR
import let       NIO.IPPROTO_TCP
import let       NIO.TCP_NODELAY
import enum      NIOHTTP1.HTTPServerRequestPart
import typealias NIOHTTP1.NIOHTTPServerUpgradeConfiguration
import struct    NIOConcurrencyHelpers.NIOLock
import Atomics

/**
 * http.Server
 *
 * Represents a HTTP server. That is, a TCP listening server handling HTTP
 * protocol messages.
 *
 * You don't usually create those objects directly, but rather using the
 * `http.createServer` global function, like so:
 *
 *     http.createServer { req, res in
 *       res.writeHead(200, [ "Content-Type": "text/html" ])
 *       res.end("<h1>Hello World</h1>")
 *     }
 *     .listen(1337)
 *
 * Supported events:
 *
 *   onRequest (req, res)
 *   - req: `http.IncomingMessage`
 *   - res: `http.ServerResponse`
 */
open class Server: ErrorEmitter, CustomStringConvertible {
  
  private static let serverID = Atomics.ManagedAtomic<Int>(0)

  public  let id        : Int
  public  let log       : Logger
  private var didRetain = false
  private let txID      = Atomics.ManagedAtomic<Int>(0)
  private let lock      = NIOLock()

  /**
   * The initializer for `Server`. This is intended for subclasses. Framework
   * users should use
   *
   *     http.createServer { req, res in
   *       ...
   *     }
   *
   * instead.
   */
  public init(log: Logger = .init(label: "μ.http")) {
    self.id  = Server.serverID.wrappingIncrementThenLoad(ordering: .relaxed)
    self.log = log
    super.init()
  }
  deinit {
    if didRetain {
      core.release()
      didRetain = false
    }
  }

  @discardableResult
  open func listen(_ port      : Int?   = nil,
                   _ host      : String = "localhost",
                   backlog     : Int  = 512,
                   onListening : ( ( Server ) -> Void)? = nil) -> Self
  {
    addDefaultListener(onListening)
    listen(backlog: backlog) { bootstrap in
      // TBD: does 0 trigger the wildcard port?
      return bootstrap.bind(host: host, port: port ?? 0)
    }
    return self
  }
  @discardableResult
  open func listen(unixSocket : String = "express.socket",
                   backlog    : Int    = 256,
                   onListening : ( ( Server ) -> Void)? = nil) -> Self
  {
    addDefaultListener(onListening)
    listen(backlog: backlog) { bootstrap in
      return bootstrap.bind(unixDomainSocketPath: unixSocket)
    }
    return self
  }
  
  private func addDefaultListener(_ listener: ( ( Server ) -> Void)?) {
    guard let listener = listener else { return }
    
    // essentially emulate `once`
    var pendingServer : Server? = self
    onListening { eventServer in
      guard let server = pendingServer else { return }
      pendingServer = nil
      assert(eventServer === server)
      listener(server)
    }
  }

  private func listen(backlog: Int,
                      bind: ( ServerBootstrap ) -> EventLoopFuture<Channel>)
  {
    let bootstrap = createServerBootstrap(backlog)
    
    didRetain = true
    core.retain()

    bind(bootstrap)
      .whenComplete { result in
        switch result {
          case .success(let channel):
            self.registerChannel(channel)

          case .failure(let error):
            self.emit(error: error)
            self.core.release(); self.didRetain = false
        }
      }
  }

  /**
   * Returns true if the server is listening on some socket/channel.
   */
  public var listening : Bool {
    lock.lock()
    let flag = !_channels.isEmpty
    lock.unlock()
    return flag
  }
  
  /**
   * Returns the socket addresses the server is listening on. Empty when the
   * server is not yet listening on anything.
   */
  public var listenAddresses : [ SocketAddress ] {
    lock.lock()
    let addresses = _channels.compactMap { $0.localAddress }
    lock.unlock()
    return addresses
  }

  private var _channels = [ Channel ]()
  private func registerChannel(_ channel: Channel) {
    lock.lock()
    _channels.append(channel)
    var listeners = _listeningListeners
    lock.unlock()
    
    listeners.emit(self)
    
    if let address = channel.localAddress {
      log.debug("Server running on: \(address)")
    }
    else {
      log.info("Server running, but channel has no address: \(channel)")
    }
  }
  
  override open func emit(error: Error) {
    log.error("server error: \(error)")
    super.emit(error: error)
  }
  
  
  // MARK: - Events
  
  // Note: This does NOT support once!
  private var _requestListeners =
    EventListenerSet<( IncomingMessage, ServerResponse )>()
  private var _continueListeners =
    EventListenerSet<( IncomingMessage, ServerResponse )>()
  private var _expectListeners =
    EventListenerSet<( IncomingMessage, ServerResponse )>()
  private var _listeningListeners =
    EventListenerSet<Server>()

  private var hasRequestListeners : Bool {
    lock.lock()
    let isEmpty = _requestListeners.isEmpty
    lock.unlock()
    return !isEmpty
  }

  @discardableResult
  public func onRequest(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.lock()
    _requestListeners.add(execute)
    lock.unlock()
    return self
  }
  @discardableResult
  public func onCheckContinue(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.lock()
    _continueListeners.add(execute)
    lock.unlock()
    return self
  }
  @discardableResult
  public func onCheckExpectation(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.lock()
    _expectListeners.add(execute)
    lock.unlock()
    return self
  }
  
  @discardableResult
  public func onListening(execute: @escaping ( Server ) -> Void) -> Self {
    lock.lock()
    _listeningListeners.add(execute)
    lock.unlock()
    if listening { execute(self) }
    return self
  }

  private func emitContinue(request: IncomingMessage, response: ServerResponse)
  {
    lock.lock()
    var listeners = _continueListeners // Note: No `once` support!
    lock.unlock()
    if listeners.isEmpty { // Note: This does NOT work w/ NIO 2.12.0
      response.writeContinue()
    }
    else {
      listeners.emit(( request, response ))
    }
  }
  private func emitExpect(request: IncomingMessage, response: ServerResponse)
              -> Bool
  {
    lock.lock()
    var listeners = _expectListeners // Note: No `once` support!
    lock.unlock()
    if listeners.isEmpty {
      response.status = .expectationFailed
      response.end()
      return false
    }
    else {
      listeners.emit(( request, response ))
      return true
    }
  }


  // MARK: - Handle Requests

  private func handle(request: IncomingMessage, response: ServerResponse)
               -> Bool
  {
    // aka onRequest
    lock.lock()
    var listeners = _requestListeners // Note: No `once` support!
    lock.unlock()
    guard !listeners.isEmpty else { return false }
    
    listeners.emit(( request, response ))
    return true
  }
  
  private func feed(request: IncomingMessage, data: Buffer) {
    request.push(data)
  }
  
  private func end(request: IncomingMessage) {
    assert(!request.complete)
    request.complete = true
  }
  
  private func cancel(request: IncomingMessage, response: ServerResponse) {
    // TODO
    log.error("cancel is not implemented.")
  }
  
  private func emitError(_ error: Swift.Error,
                         transaction: ( IncomingMessage, ServerResponse )?)
  {
    if let ( request, _ ) = transaction {
      // TBD: we also need to tell the response if the channel was closed?
      request.emit(error: error)
    }
    else {
      emit(error: error)
    }
  }

  
  // MARK: - NIO Boilerplate

  open var upgradeConfiguration : NIOHTTPServerUpgradeConfiguration? {
    willSet {
      if listening {
        log.warn("Setting new upgrade config, but server is already listening!")
      }
    }
  }

  private func createServerBootstrap(_ backlog : Int) -> ServerBootstrap {
    let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),
                                             SO_REUSEADDR)
    let noDelayOp    = ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY)
    
    let upgrade      = upgradeConfiguration
    
    let bootstrap = ServerBootstrap(group: core.eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: Int32(backlog))
      .serverChannelOption(reuseAddrOpt, value: 1)
      
      .childChannelInitializer { channel in
        return channel.pipeline
          .configureHTTPServerPipeline(withServerUpgrade: upgrade)
          .flatMap {
            return channel.pipeline.addHandler(HTTPHandler(server: self),
                                               name: Server.httpHandlerName)
          }
      }
      
      .childChannelOption(noDelayOp,    value: 1)
      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, // TBD
                          value: 1)
    return bootstrap
  }
  
  /**
   * This is the name of the HTTP handler in the SwiftNIO pipeline.
   *
   * It is a low-level internal a user doesn't usually have to touch.
   */
  public static let httpHandlerName: String = "μ.http.server.handler"
  
  private final class HTTPHandler : ChannelInboundHandler,
                                    RemovableChannelHandler
  {

    typealias InboundIn = HTTPServerRequestPart
    
    // TODO: Assign request ID and other logging metadata!
    
    private let server      : Server
    private var transaction : ( id       : Int,
                                request  : IncomingMessage,
                                response : ServerResponse )?
    private var waitForEnd  = false

    init(server: Server) {
      self.server = server
    }
    
    final func channelRead(context: ChannelHandlerContext, data: NIOAny) {
      let log     = server.log
      let reqPart = unwrapInboundIn(data)
      
      switch reqPart {
        case .head(let head):
          // TBD: If pipelining is on, there could be multiple requests coming
          //      in.
          if let ( id, request, response ) = transaction {
            assert(transaction == nil, "already processing an HTTP request?!")
            log.error("got another HTTP request while \(id) is active")
            server.cancel(request: request, response: response)
            self.transaction = nil
          }

          guard server.hasRequestListeners else {
            errorCaught(context: context, error: HTTPHandlerError.noListeners)
            return
          }

          let id  = server.txID.wrappingIncrementThenLoad(ordering: .relaxed)
          var log = Logger(label: "μ.http")
          log[metadataKey: "request-id"] = "\(id)"
          
          // TBD:  Should the ServerResponse know its IncomingMessage?
          let request  = IncomingMessage(head, socket: context.channel,
                                         log: log)
          
          let response = ServerResponse(channel: context.channel, log: log)
          response.version = head.version
          
          if head.version.major == 1 {
            let connectionHeaderCount = head
              .headers[canonicalForm: "connection"]
              .lazy
              .map    { $0.lowercased() }
              .filter { $0 == "keep-alive" || $0 == "close" }
              .count
            if connectionHeaderCount == 0 { // no connection headers
              if head.isKeepAlive, head.version.minor == 0 {
                response.headers.add(name: "Connection", value: "keep-alive")
              }
              else if !head.isKeepAlive, head.version.minor >= 1 {
                response.headers.add(name: "Connection", value: "close")
              }
            }
          }

          self.transaction = ( id, request, response )
          self.waitForEnd  = false
          assert(!request.complete)
          
          // The transaction ends when the response is done, not when the
          // request was read completely!
          response.onceFinish {
            guard let ( id, request, aresponse ) = self.transaction else {
              return
            }
            guard aresponse === response else { return }
            
            // Consume rest of request if it wasn't read already
            if request.complete {
              log.debug("finished HTTP transaction \(id)")
              self.transaction = nil
              self.waitForEnd  = false
            }
            else {
              log.debug("finished response, but request did not end yet \(id)")
              self.waitForEnd  = true
              let autoReadOption = ChannelOptions.Types.AutoReadOption()
              // make sure we read the request
              _ = context.channel.setOption(autoReadOption, value: true)
            }
          }
          
          #if false
            // This is not quite right, let's disable this until we have proper
            // back-pressure. We should only disable reading if the
            // IncomingMessage stream is full.
            // Disabling it upfront is wrong, because no one might ever register
            // for data-processing, and read affects reading the request end as
            // well!
            request.flowingToggler = { flowing in
              let autoReadOption = ChannelOptions.Types.AutoReadOption()
              _ = context.channel.setOption(autoReadOption, value: flowing)
            }
            
            // Disable auto-read until there is a reader
            let autoReadOption = ChannelOptions.Types.AutoReadOption()
            _ = context.channel.setOption(autoReadOption, value: false)
          #endif
          
          // MARK: - Expect Handling
          
          for expect in request.headers["Expect"] {
            if expect == "100-continue" {
              server.emitContinue(request: request, response: response)
            }
            else {
              if !server.emitExpect(request: request, response: response) {
                self.waitForEnd  = !request.readableEnded
                self.transaction = nil
                return
              }
            }
          }
          
          // MARK: - Start Request
          
          if !response.writableEnded { // already processed, e.g. by expect
            if !server.handle(request: request, response: response) {
              errorCaught(context: context, error: HTTPHandlerError.noListeners)
            }
          }
        
        case .body(let bytes):
          if let ( _, request, _ ) = transaction {
            server.feed(request: request, data: Buffer(bytes))
          }
          else if !waitForEnd {
            log.error("received HTTP body data, but no TX is running! Closing.")
            assert(transaction != nil,
                   "body data, but no transaction is running?")
            errorCaught(context: context,
                        error: HTTPHandlerError.bodyWithoutTransaction)
          }
        
        case .end:
          if let ( id, request, response ) = transaction {
            // can come in after response end! need to clear TX in this case
            server.end(request: request)
            
            if response.writableEnded {
              log.debug("finished HTTP transaction \(id)")
              self.transaction = nil
              self.waitForEnd  = false
            }
            else {
              log.debug("finished request, but response did not end yet \(id)")
            }
          }
          else if !waitForEnd {
            log.error("received HTTP end, but no TX is running! Closing.")
            assert(transaction != nil,
                   "got end, but no transaction is running?")
            errorCaught(context: context,
                        error: HTTPHandlerError.endWithoutTransaction)
          }
          waitForEnd = false
      }
    }
    
    enum HTTPHandlerError: Swift.Error {
      case bodyWithoutTransaction, endWithoutTransaction
      case noListeners
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
      if let ( id, request, response ) = transaction {
        // HTTPParserError.invalidEOFState
        server.log.error("HTTP error in TX \(id), closing connection: \(error)")
        server.emitError(error, transaction: ( request, response ))
      }
      else {
        server.log.error("HTTP error, closing connection: \(error)")
        server.emitError(error, transaction: nil)
      }
      self.transaction = nil
      context.close(promise: nil)
    }
  }
  
  
  // MARK: - Description
  
  public var description: String {
    var ms = "<http.Server[\(id)]: #tx=\(txID.load(ordering: .relaxed))"
    
    let addrs = listenAddresses
    if addrs.isEmpty {
      ms += " not-listening"
    }
    else {
      ms += " "
      ms += addrs.map { String(describing: $0) }.joined(separator: ",")
    }
    
    if !didRetain { ms += " not-retaining" }
    ms += ">"
    return ms
  }
}
