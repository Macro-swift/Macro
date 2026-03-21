//
//  Server.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

#if canImport(Glibc)
  import Glibc  // ECONNRESET,EPIPE
#elseif canImport(Darwin)
  import Darwin // ECONNRESET,EPIPE
#endif
import MacroCore // ErrorEmitter,EventListenerSet,MacroCore,Buffer
import Logging   // Logger
import NIOCore   // IOError
import NIO       // NIOAny,EventLoopFuture,ServerBootstrap,Channel,...
import NIOHTTP1  // HTTPServerRequestPart,NIOHTTPServerUpgradeConfiguration
import NIOConcurrencyHelpers // NIOLock
import Atomics
import xsys

/**
 * http.Server
 *
 * Represents a HTTP server. That is, a TCP listening server handling HTTP
 * protocol messages.
 *
 * You don't usually create those objects directly, but rather using the
 * ``http/createServer(handler:)`` global function, like so:
 * ```swift
 * http.createServer { req, res in
 *   res.writeHead(200, [ "Content-Type": "text/html" ])
 *   res.end("<h1>Hello World</h1>")
 * }
 * .listen(1337)
 * ```
 * 
 * Each server instance has an associated, unique, id.
 * Each HTTP request (``http/IncomingMessage``) gets assigned an own transaction
 * id.
 * 
 * The server retains the Macro runloop when it starts to listen, and releases
 * it when it is getting deallocated.
 *
 * Supported events:
 * - ``Server/onRequest(execute:)``
 *   - req: ``http/IncomingMessage``
 *   - res: ``http/ServerResponse``
 * - ``Server/onCheckContinue(execute:)``
 * - ``Server/onCheckExpectation(execute:)``
 * - ``Server/onListening(execute:)``
 */
open class Server: ErrorEmitter, CustomStringConvertible {
  
  private static let serverID = Atomics.ManagedAtomic<Int>(0)

  public  let id        : Int
  public  var options   : Options
  private var didRetain = false
  private let txID      = Atomics.ManagedAtomic<Int>(0)
  public  let lock      = NIOLock()

  @inlinable
  public  var log       : Logger { return options.log }

  /**
   * Configuration options for the HTTP server, mirrors
   * Node.js `http.createServer(options)`.
   */
  public struct Options {

    public  var log = Logger(label: "μ.http")

    /**
     * Milliseconds of inactivity before an idle connection is closed. Applies 
     * before the first request and between keep-alive requests. 
     * Set to 0 to disable, default is 5s.
     */
    public var keepAliveTimeout = 5_000

    /// Enable TCP keep-alive probes on accepted connections (default: true).
    public var keepAlive = true

    /**
     * Set `TCP_NODELAY` on connections to disable Nagle's algorithm. 
     * (default true).
     */
    public var noDelay = true

    @inlinable
    public init() {}

    /**
     * Create options with explicit values.
     *
     * - Parameters:
     *   - log:              Logger for server messages.
     *   - keepAliveTimeout: Idle timeout in ms (0 = off).
     *   - keepAlive:        Enable TCP keep-alive probes.
     *   - noDelay:          Set `TCP_NODELAY` on sockets.
     */
    @inlinable
    public init(log              : Logger = Logger(label: "μ.http"),
                keepAliveTimeout : Int    = 5_000,
                keepAlive        : Bool   = true,
                noDelay          : Bool   = true)
    {
      self.log              = log
      self.keepAliveTimeout = keepAliveTimeout
      self.keepAlive        = keepAlive
      self.noDelay          = noDelay
    }
  }

  /**
   * The initializer for `Server`. This is intended for subclasses. Framework
   * users should use:
   * ```swift
   * http.createServer { req, res in
   *       ...
   * }
   * ```
   * instead.
   * 
   * - Parameters:
   *   - options: Server configuration options.
   *   - log:     A Logger object to use.
   */
  public init(_ options: Options = Options()) {
    self.id      = Server.serverID.wrappingIncrementThenLoad(ordering: .relaxed)
    self.options = options
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
                   backlog     : Int    = 512,
                   onListening : (@Sendable ( Server ) -> Void)? = nil) -> Self
  {
    addDefaultListener(onListening)
    listen(bootstrap: createServerBootstrap(backlog))
    { bootstrap in
      // TBD: does 0 trigger the wildcard port?
      return bootstrap.bind(host: host, port: port ?? 0)
    }
    return self
  }
  @discardableResult
  open func listen(unixSocket  : String = "express.socket",
                   backlog     : Int    = 512,
                   onListening : (@Sendable ( Server ) -> Void)? = nil) -> Self
  {
    addDefaultListener(onListening)
    listen(bootstrap: createServerBootstrap(backlog)) { bootstrap in
      return bootstrap.bind(unixDomainSocketPath: unixSocket)
    }
    return self
  }
  
  private func addDefaultListener(_ listener: (@Sendable ( Server ) -> Void)?) {
    guard let listener = listener else { return }
    let isListening = lock.withLock {
      let token = _listeningListeners.once(listener)
      let isListening = !_channels.isEmpty
      if isListening { _listeningListeners.removeListener(token) }
      return isListening
    }
    if isListening { listener(self) }
  }
  
  /**
   * Listen with a specific SwiftNIO `ServerBootstrap` setup,
   * provided by the user.
   *
   * This is a low level method, intended for internal use primarily.
   */
  open func listen(bootstrap: ServerBootstrap,
                   bind: ( ServerBootstrap ) -> EventLoopFuture<Channel>)
  {
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
    return lock.withLock { return !_channels.isEmpty }
  }
  
  /**
   * Returns the socket addresses the server is listening on. Empty when the
   * server is not yet listening on anything.
   */
  public var listenAddresses : [ NIOCore.SocketAddress ] {
    return lock.withLock { return _channels.compactMap { $0.localAddress } }
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
    return !lock.withLock { return _requestListeners.isEmpty }
  }

  @discardableResult
  public func onRequest(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.withLockVoid { _requestListeners.add(execute) }
    return self
  }
  @discardableResult
  public func onCheckContinue(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.withLockVoid { _continueListeners.add(execute) }
    return self
  }
  @discardableResult
  public func onCheckExpectation(execute:
                @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
  {
    lock.withLockVoid { _expectListeners.add(execute)}
    return self
  }
  
  @discardableResult
  public func onListening(execute: @escaping @Sendable (Server) -> Void) -> Self
  {
    lock.withLockVoid { _listeningListeners.add(execute) }
    if listening { execute(self) }
    return self
  }

  private func emitContinue(request: IncomingMessage, response: ServerResponse)
  {
    var listeners = lock.withLock {
      return _continueListeners // Note: No `once` support!
    }
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
    var listeners = lock.withLock {
      return _expectListeners // Note: No `once` support!
    }
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
    var listeners = lock.withLock {
      return _requestListeners // Note: No `once` support!
    }
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
    let reuseAddrOpt = ChannelOptions.socket(SocketOptionLevel(xsys.SOL_SOCKET),
                                             xsys.SO_REUSEADDR)
    let noDelayOp = ChannelOptions.socket(xsys.IPPROTO_TCP, TCP_NODELAY)
    #if canImport(Darwin) // TBD: move to xsys?
      let cSO_KEEPALIVE = Darwin.SO_KEEPALIVE
    #elseif canImport(Glibc)
      let cSO_KEEPALIVE = Glibc.SO_KEEPALIVE
    #endif
    let keepAliveOp = ChannelOptions.socket(SocketOptionLevel(xsys.SOL_SOCKET),
                                            Int32(cSO_KEEPALIVE))

    let upgrade = upgradeConfiguration
    let opts    = options

    let bootstrap = ServerBootstrap(group: core.eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: Int32(backlog))
      .serverChannelOption(reuseAddrOpt, value: 1)
      
      .childChannelInitializer { channel in
        let timeoutMS = opts.keepAliveTimeout
        return channel.pipeline
          .configureHTTPServerPipeline(withServerUpgrade: upgrade)
          .flatMap {
            guard timeoutMS > 0 else {
              return channel.eventLoop.makeSucceededVoidFuture()
            }
            let idle = 
              IdleStateHandler(readTimeout: .milliseconds(Int64(timeoutMS)))
            #if compiler(>=5.10)
            nonisolated(unsafe) let h : ChannelHandler = idle
            #else
            let h : ChannelHandler = idle
            #endif
            return channel.pipeline
              .addHandler(h, name: Server.idleHandlerName)
              .flatMap {
                channel.pipeline.addHandler(CloseOnIdleHandler(),
                                            name: Server.closeOnIdleHandlerName)
              }
          }
          .flatMap {
            channel.pipeline.addHandler(HTTPHandler(server: self),
                                        name: Server.httpHandlerName)
          }
      }

      .childChannelOption(reuseAddrOpt, value: 1)
      .childChannelOption(noDelayOp,    value: opts.noDelay   ? 1 : 0)
      .childChannelOption(keepAliveOp,  value: opts.keepAlive ? 1 : 0)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    return bootstrap
  }
  
  /**
   * This is the name of the HTTP handler in the SwiftNIO pipeline.
   *
   * It is a low-level internal a user doesn't usually have to touch.
   */
  public static let httpHandlerName: String = "μ.http.server.handler"
  static let idleHandlerName        = "μ.http.idle"
  static let closeOnIdleHandlerName = "μ.http.idle.close"

  /// Closes the channel when an idle timeout fires.
  /// Added to the pipeline alongside `IdleStateHandler` and removed after the 
  /// first HTTP request arrives.
  private final class CloseOnIdleHandler: ChannelInboundHandler, 
                                          RemovableChannelHandler
  {
    typealias InboundIn = HTTPServerRequestPart

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
      if event is IdleStateHandler.IdleStateEvent {
        context.close(promise: nil)
      }
      else {
        context.fireUserInboundEventTriggered(event)
      }
    }
  }

  private final class HTTPHandler: ChannelInboundHandler,
                                   RemovableChannelHandler
  {

    typealias InboundIn = HTTPServerRequestPart
    
    private let server      : Server
    private var transaction : ( id       : Int,
                                 request  : IncomingMessage,
                                 response : ServerResponse )?
    private var waitForEnd  = false
    
    private let idle  : ChannelHandler? // cache this, should be fine?
    private let close : CloseOnIdleHandler?

    init(server: Server) {
      self.server = server
      let keepAliveTimeoutMS = Int64(server.options.keepAliveTimeout)
      if keepAliveTimeoutMS > 0 {
        self.idle = 
          IdleStateHandler(readTimeout: .milliseconds(keepAliveTimeoutMS))
        self.close = CloseOnIdleHandler()
      }
      else { self.idle = nil; self.close = nil }
    }

    private func removeIdleHandlers(_ context: ChannelHandlerContext) {
      guard idle != nil else { return }
      context.pipeline.removeHandler(name: Server.idleHandlerName)
                      .whenFailure { _ in }
      context.pipeline.removeHandler(name: Server.closeOnIdleHandlerName)
                      .whenFailure { _ in }
    }

    private func addIdleHandlers(_ context: ChannelHandlerContext) {
      guard let idle = idle else { return }
      #if compiler(>=5.10)
      nonisolated(unsafe) let handler : ChannelHandler = idle
      #else
      let handler : ChannelHandler = idle
      #endif
      guard let close = self.close else { return }
      context.pipeline
        .addHandler(handler, name: Server.idleHandlerName, position: .first)
        .flatMap {
          context.pipeline.addHandler(close,
                                      name: Server.closeOnIdleHandlerName,
                                      position: .after(handler))
        }
        .whenFailure { _ in }
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
          let request  = IncomingMessage(head, socket: context.channel, log:log)
          
          let response = ServerResponse(channel: context.channel, log: log)
          response.version = head.version

          // remember the time the response object got created.
          // The Date header will be set on header flush if sendDate is on and
          // the the header is missing.
          response.date = time_t.now
          
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

          // Remove idle timeout while request is being processed, we might
          // take longer to produce responses than waiting for new data.
          self.removeIdleHandlers(context)

          // The transaction ends when the response is done, not when the
          // request was read completely!
          response.onceFinish {
            guard let ( id, request, aresponse ) = self.transaction else {
              return
            }
            guard aresponse === response else { 
              assertionFailure("Got incorrect response object?")
              return 
            }

            // Re-add idle timeout for the keep-alive idle period (close if no 
            // next request arrives within the timeout).
            // TBD: What if the next data already arrived?
            self.addIdleHandlers(context)
            
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
      
      func isClientDisconnect(_ error: Error) -> Bool {
        guard let e = error as? IOError else { return false }
        // ECONNRESET: client reset the connection
        // EPIPE: client closed before server finished writing
        return e.errnoCode == ECONNRESET || e.errnoCode == EPIPE
      }
      
      if let ( id, request, response ) = transaction {
        self.transaction = nil
        if isClientDisconnect(error) {
          server.log.warning("HTTP client disconnect in TX \(id): \(error)")
        }
        else {
          server.log.error("HTTP error in TX \(id), closing: \(error)")
          server.emitError(error, transaction: ( request, response ))
        }
      }
      else { // We are not in a transaction. disconnect is not an error.
        if isClientDisconnect(error) {
          server.log.trace("HTTP client disconnect, closing: \(error)")
        }
        else {
          server.log.error("HTTP error, closing connection: \(error)")
          server.emitError(error, transaction: nil)
        }
      }
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
