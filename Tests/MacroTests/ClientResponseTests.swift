//
//  ClientResponseTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
@testable import http
@testable import Macro
@testable import MacroTestUtilities
import class http.IncomingMessage
import class http.ServerResponse

final class ClientResponseTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  /// A request that never receives anything has no response to give to
  /// an `onResponse` listener, so it reports on the request itself.
  /// Neither a fabricated response nor an `end` may show up.
  func testFailureWithNoResponseReportsOnRequest() {
    let port = startServer { _ in } // accepts, then stays silent

    let exp = expectation(description: "request failed")
    exp.assertForOverFulfill = false
    let sawResponse = Ref(false)
    let sawEnd      = Ref(false)
    let sawError    = Ref<Error?>(nil)

    let req = http.get(options: options(port: port, timeout: 1)) { res in
      sawResponse.value = true
      res.onEnd { sawEnd.value = true; exp.fulfill() }
    }
    req.onError { error in
      sawError.value = error
      exp.fulfill()
    }

    waitForExpectations(timeout: 10)
    XCTAssertNotNil(sawError   .value, "error not reported on the request")
    XCTAssertFalse (sawResponse.value, "a response was made up")
    XCTAssertFalse (sawEnd     .value, "a failed request was ended")
  }

  func testFailureIsNotReportedAsAnEmptyOK() {
    let port = startServer { _ in }

    let exp = expectation(description: "request failed")
    exp.assertForOverFulfill = false
    let statusCode = Ref(-1)
    let body       = Ref<String?>(nil)

    let req = http.get(options: options(port: port, timeout: 1)) { res in
      statusCode.value = res.statusCode
      res | concat { buffer in body.value = (try? buffer.toString()) ?? "" }
      res.onEnd { exp.fulfill() }
    }
    req.onError { _ in exp.fulfill() }

    waitForExpectations(timeout: 10)
    XCTAssertEqual(statusCode.value, -1, "got a status for a failed request")
    XCTAssertNil  (body      .value,     "got a body for a failed request")
  }

  func testSuccessfulResponse() {
    let port = startServer { res in
      res.writeHead(200, [ "Content-Type": "text/plain" ])
      res.write("hello")
      res.end()
    }

    let exp = expectation(description: "response ended")
    exp.assertForOverFulfill = false
    let statusCode = Ref(0)
    let body       = Ref("")
    let sawError   = Ref(false)

    let req = http.get(options: options(port: port)) { res in
      statusCode.value = res.statusCode
      res.onError { _ in sawError.value = true; exp.fulfill() }
      res | concat { buffer in body.value = (try? buffer.toString()) ?? "" }
      res.onEnd { exp.fulfill() }
    }
    req.onError { _ in sawError.value = true; exp.fulfill() }

    waitForExpectations(timeout: 5)
    XCTAssertEqual(statusCode.value, 200)
    XCTAssertEqual(body.value, "hello")
    XCTAssertFalse(sawError.value, "an error was reported for a good request")
  }

  func testTruncatedBodyIsNotEnded() {
    let port = startServer { res in
      res.writeHead(200, [ "Content-Length": "100" ])
      _ = res.write("0123456789")
      guard let socket = res.socket else { return }
      socket.flush()
      socket.eventLoop.execute { _ = socket.close() }
    }

    let exp = expectation(description: "truncated")
    exp.assertForOverFulfill = false
    let sawResponse = Ref(false)
    let sawEnd      = Ref(false)
    let sawError    = Ref(false)

    let req = http.get(options: options(port: port, timeout: 2)) { res in
      sawResponse.value = true
      res.onError { _ in sawError.value = true; exp.fulfill() }
      res.onEnd   {      sawEnd.value   = true; exp.fulfill() }
    }
    req.onError { _ in sawError.value = true; exp.fulfill() }

    waitForExpectations(timeout: 10)
    XCTAssertFalse(sawResponse.value, "a partial response was delivered")
    XCTAssertTrue (sawError   .value, "truncated body reported no error")
    XCTAssertFalse(sawEnd     .value, "truncated body was ended as complete")
  }

  /// `timeout` is milliseconds and `timeoutInterval` is seconds. The
  /// getter used to hand the raw milliseconds out as seconds, which
  /// made every client timeout 1000x longer than asked for.
  func testTimeoutIntervalRoundTrips() {
    var options = http.ClientRequestOptions()
    XCTAssertNil(options.timeout)
    XCTAssertNil(options.timeoutInterval)

    options.timeoutInterval = 2.5
    XCTAssertEqual(options.timeout, 2500)
    XCTAssertEqual(options.timeoutInterval, 2.5)

    options.timeout = 500
    XCTAssertEqual(options.timeoutInterval, 0.5)
  }

  // MARK: - Helpers
  
  private final class Ref<T>: @unchecked Sendable { // make T Sendable
    var value: T
    init(_ v: T) { value = v }
  }

  private func startServer(_ handler: @escaping ( ServerResponse ) -> Void)
               -> Int
  {
    let listenExp = expectation(description: "listening")
    let portRef   = Ref(0)

    let server = http.createServer { _, res in handler(res) }
    server.listen(0, "127.0.0.1") { server in
      if let addr = server.listenAddresses.first, let p = addr.port {
        portRef.value = p
      }
      listenExp.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNotEqual(portRef.value, 0, "Server did not start")
    return portRef.value
  }

  private func options(port: Int, timeout: TimeInterval = 3)
               -> http.ClientRequestOptions
  {
    return http.ClientRequestOptions(host    : "127.0.0.1",
                                     port    : port,
                                     path    : "/",
                                     timeout : Int(timeout * 1000))
  }

  static let allTests = [
    ( "testFailureWithNoResponseReportsOnRequest" ,
      testFailureWithNoResponseReportsOnRequest ),
    ( "testFailureIsNotReportedAsAnEmptyOK" ,
      testFailureIsNotReportedAsAnEmptyOK ),
    ( "testSuccessfulResponseStillEnds" , testSuccessfulResponse          ),
    ( "testTruncatedBodyIsNotEnded"     , testTruncatedBodyIsNotEnded     ),
    ( "testTimeoutIntervalRoundTrips"   , testTimeoutIntervalRoundTrips   )
  ]
}
