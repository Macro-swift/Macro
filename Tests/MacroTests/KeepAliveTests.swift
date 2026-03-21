//
//  KeepAliveTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import Foundation
@testable import http
@testable import Macro
@testable import MacroTestUtilities
import class http.IncomingMessage
import class http.ServerResponse
#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

final class KeepAliveTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - Helpers

  private func startServer(keepAliveTimeout: Int = 5_000,
                           handler: @escaping 
                             (IncomingMessage, ServerResponse) -> Void
                           = { _, res in res.writeHead(200); res.end() }) -> Int
  {
    let listenExp = expectation(description: "listening")
    nonisolated(unsafe) var port = 0

    let server = http.createServer(handler: handler)
    server.options.keepAliveTimeout = keepAliveTimeout
    server.listen(0) { server in
      if let addr = server.listenAddresses.first, let p = addr.port {
        port = p
      }
      listenExp.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNotEqual(port, 0, "Server did not start")
    return port
  }

  @discardableResult
  private func request(_ url: URL, session: URLSession, method: String = "GET")
               -> (Data, HTTPURLResponse)?
  {
    let exp      = expectation(description: "\(method) \(url)")
    var result   : (Data, HTTPURLResponse)?
    var reqError : Error?

    var req = URLRequest(url: url)
    req.httpMethod = method
    let task = session.dataTask(with: req) {
      data, response, error in
      reqError = error
      if let data = data, let http = response as? HTTPURLResponse {
        result = (data, http)
      }
      exp.fulfill()
    }
    task.resume()
    waitForExpectations(timeout: 10)
    if let error = reqError { XCTFail("Request failed: \(error)") }
    return result
  }

  private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.httpMaximumConnectionsPerHost = 1
    return URLSession(configuration: config)
  }

  // MARK: - Tests

  static let allTests = [
    ("testKeepAliveMultipleRequests"    , testKeepAliveMultipleRequests),
    ("testConnectionSurvivesIdlePeriod" , testConnectionSurvivesIdlePeriod),
    ("testConnectionCloseIsHonored"     , testConnectionCloseIsHonored),
    ("testIdleConnectionClosedBeforeFirstRequest",
     testIdleConnectionClosedBeforeFirstRequest)
  ]

  func testKeepAliveMultipleRequests() {
    let port    = startServer()
    let session = makeSession()
    defer { session.invalidateAndCancel() }

    let url = URL(string: "http://localhost:\(port)/")!

    for i in 0..<5 {
      guard let (_, response) = request(url, session: session) else {
        XCTFail("Request \(i) returned no result")
        return
      }
      XCTAssertEqual(response.statusCode, 200, "Request \(i) status")
      let conn = response.value(forHTTPHeaderField: "Connection") ?? ""
      XCTAssertNotEqual(conn.lowercased(), "close",
                        "Request \(i) has Connection: close")
    }
  }

  func testConnectionSurvivesIdlePeriod() {
    let port    = startServer()
    let session = makeSession()
    defer { session.invalidateAndCancel() }

    let url = URL(string: "http://localhost:\(port)/")!

    guard let (_, r1) = request(url, session: session) else { 
      return XCTFail("First request failed") 
    }
    XCTAssertEqual(r1.statusCode, 200)

    // Wait 3 seconds (idle between requests)
    let idleExp = expectation(description: "idle wait")
    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { 
      idleExp.fulfill() 
    }
    waitForExpectations(timeout: 5)

    guard let (_, r2) = request(url, session: session) else {
      return XCTFail("Request after idle failed") 
    }
    XCTAssertEqual(r2.statusCode, 200)
  }

  func testConnectionCloseIsHonored() {
    let port = startServer { _, res in
      res.setHeader("Connection", "close")
      res.writeHead(200)
      res.end()
    }
    let session = makeSession()
    defer { session.invalidateAndCancel() }

    let url = URL(string: "http://localhost:\(port)/")!

    guard let (_, r1) = request(url, session: session) else { 
      return XCTFail("Request failed") 
    }
    XCTAssertEqual(r1.statusCode, 200)

    // Another request should still work (new connection)
    guard let (_, r2) = request(url, session: session) else { 
      return XCTFail("Second request failed") 
    }
    XCTAssertEqual(r2.statusCode, 200)
  }

  /// A connection that receives no data should be closed
  /// by the server after `keepAliveTimeout` ms.
  func testIdleConnectionClosedBeforeFirstRequest() {
    let timeoutMS = 2_000
    let port = startServer(keepAliveTimeout: timeoutMS)

    // Open a raw TCP connection via InputStream, send
    // nothing, and wait for the server to close it.
    let exp = expectation(description: "connection closed")

    var inputStream  : InputStream?
    var outputStream : OutputStream?
    Stream.getStreamsToHost(withName: "localhost", port: port,
                            inputStream: &inputStream,
                            outputStream: &outputStream)
    guard let input = inputStream else {
      XCTFail("Could not create stream")
      return
    }
    input.open()

    DispatchQueue.global().async {
      // Read until the server closes (returns 0 bytes)
      var buf = [ UInt8 ](repeating: 0, count: 1)
      let n = input.read(&buf, maxLength: 1)
      // n <= 0 means server closed or error
      XCTAssertLessThanOrEqual(n, 0, "Expected server to close idle connection")
      input.close()
      exp.fulfill()
    }

    // The server should close within timeout + margin
    waitForExpectations(timeout: Double(timeoutMS) / 1000.0 + 3)
  }
}
