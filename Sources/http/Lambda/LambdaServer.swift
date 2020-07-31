//
//  LambdaServer.swift
//  Macro
//
//  Created by Helge Heß
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if canImport(AWSLambdaEvents)

import func     Foundation.setenv
import func     Foundation.exit
import struct   Logging.Logger
import class    NIO.EventLoopFuture
import class    MacroCore.ErrorEmitter
import enum     MacroCore.EventListenerSet
import struct   MacroCore.Buffer
import protocol AWSLambdaRuntime.EventLoopLambdaHandler
import enum     AWSLambdaRuntime.Lambda
import enum     AWSLambdaEvents.APIGateway

extension lambda {

  /**
   * An `http.Server` lookalike, but for AWS Lambda functions addressed using
   * the AWS API Gateway V2.
   *
   * Create those server objects using `lambda.createServer`, example:
   *
   *     let server = lambda.createServer { req, res in
   *       req.log.info("request arrived in Macro land: \(req.url)")
   *       res.writeHead(200, [ "Content-Type": "text/html" ])
   *       res.end("<h1>Hello World</h1>")
   *     }
   *     server.run()
   *
   * Note that the `run` function never returns.
   */
  open class Server: ErrorEmitter {
    
    public  let log       : Logger
    private var didRetain = false

    @usableFromInline
    init(log: Logger = .init(label: "μ.http")) {
      self.log = log
      super.init()
    }
    deinit {
      if didRetain {
        core.release()
        didRetain = false
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
    private var _expectListeners =
      EventListenerSet<( IncomingMessage, ServerResponse )>()
    private var _listeningListeners =
      EventListenerSet<Server>()

    private var hasRequestListeners : Bool {
      return !_requestListeners.isEmpty
    }

    @discardableResult
    public func onRequest(execute:
                  @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
    {
      _requestListeners.add(execute)
      return self
    }
    @discardableResult
    public func onCheckExpectation(execute:
                  @escaping ( IncomingMessage, ServerResponse ) -> Void) -> Self
    {
      _expectListeners.add(execute)
      return self
    }
    
    @discardableResult
    public func onListening(execute: @escaping ( Server ) -> Void) -> Self {
      _listeningListeners.add(execute)
      if listening { execute(self) }
      return self
    }

    private func emitExpect(request: IncomingMessage, response: ServerResponse)
                -> Bool
    {
      var listeners = _expectListeners // Note: No `once` support!
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
      var listeners = _requestListeners // Note: No `once` support!
      guard !listeners.isEmpty else { return false }
      
      listeners.emit(( request, response ))
      return true
    }
    
    private func feed(request: IncomingMessage, data: Buffer) {
      request.push(data)
    }
    
    private func end(request: IncomingMessage) {
      assert(!request.complete)
      #if false // we don't have that
      request.complete = true
      #endif
    }
    
    private func cancel(request: IncomingMessage, response: ServerResponse) {
      // TODO / TBD
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
    
    private var didRun = false
    
    open var listening : Bool {
      return didRun
    }

    open func run(onRun : ( ( Server ) -> Void)? = nil) -> Never {
      assert(!didRun)
      guard !didRun else {
        fatalError("run called twice, which is impossible :-)")
      }
      didRun = true
      
      // Let "onListener" listeners know that we started running.
      if let onRun = onRun { onRun(self) }
      var listeners = _listeningListeners
      _listeningListeners.removeAll()
      listeners.emit(self)
      
      // Note: I think we can't set the core.eventLoopGroup here, because the
      //       eventLoop is only available in the Lambda context? Not sure who
      //       would even touch the MacroCore loop (vs using current).
      
      struct APIGatewayProxyLambda: EventLoopLambdaHandler {
        typealias In  = APIGateway.V2.Request
        typealias Out = APIGateway.V2.Response
        
        let server : Server

        func handle(context: Lambda.Context, event: In) -> EventLoopFuture<Out>
        {
          let promise = context.eventLoop.makePromise(of: Out.self)
          server.handle(context: context, request: event) { result in
            promise.completeWith(result)
          }
          return promise.futureResult
        }
      }
      let proxy = APIGatewayProxyLambda(server: self)
      Lambda.run(proxy)
      Foundation.exit(0) // Because `run` is not marked as Never (Issue #151)
    }
    
    private func handle(context  : Lambda.Context,
                        request  : APIGateway.V2.Request,
                        callback : @escaping
                          ( Result<APIGateway.V2.Response, Error> ) -> Void)
    {
      guard !self._requestListeners.isEmpty else {
        assertionFailure("no request listeners?!")
        return callback(.failure(ServerError.noRequestListeners))
      }

      let req = IncomingMessage(lambdaRequest: request, log: context.logger)
      let res = ServerResponse(unsafeChannel: nil, log: context.logger)
      res.cork()
      res.extra["macro.express.request"] = req // FIXME: expose in ME
            
      // The transaction ends when the response is done, not when the
      // request was read completely!
      var didFinish = false
      
      res.onceFinish {
        // convert res to gateway Response and call callback
        guard !didFinish else {
          return context.logger.error("TX already finished!")
        }
        didFinish = true
        
        callback(.success(res.asLambdaGatewayResponse))
      }
      
      res.onError { error in
        guard !didFinish else {
          return context.logger.error("Follow up error: \(error)")
        }
        didFinish = true
        callback(.failure(error))
      }
      
      // TODO: Process Expect. It's not really "ahead of sending the body",
      //       but we still need to validate the preconditions. http.Server
      //       has code for this. Do the same.
      
      do { // onRequest
        var listeners = self._requestListeners // Note: No `once` support!
        guard !listeners.isEmpty else {
          didFinish = true
          return callback(.failure(ServerError.noRequestListeners))
        }
        
        listeners.emit(( req, res ))
      }
      
      // For a streaming push, we do the lambda-send here, after announcing the
      // head.
      if !res.writableEnded { // response is already closed
        req.sendLambdaBody(request)
      }
      else {
        assert(didFinish)
      }
    }
  }

  enum ServerError: Swift.Error {
    case noRequestListeners
  }
}

#endif // canImport(AWSLambdaEvents)
