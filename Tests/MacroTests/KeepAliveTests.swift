//
//  KeepAliveTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
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

  /// Box to shuttle a value out of a `@Sendable` closure.
  private final class Ref<T>: @unchecked Sendable {
    var value: T
    init(_ v: T) { value = v }
  }

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - Helpers

  private func startServer(host: String = "127.0.0.1",
                           idleTimeout: Int = 5_000,
                           handler: @escaping
                             (IncomingMessage, ServerResponse) -> Void
                           = { _, res in res.writeHead(200); res.end() })
               -> Int
  {
    let listenExp = expectation(description: "listening")
    let portRef   = Ref(0)

    let server = http.createServer(handler: handler)
    server.options.idleTimeout = idleTimeout
    server.listen(0, host) { server in
      if let addr = server.listenAddresses.first,
         let p = addr.port
      {
        portRef.value = p
      }
      listenExp.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNotEqual(portRef.value, 0, "Server did not start")
    return portRef.value
  }

  @discardableResult
  private func request(_ url: URL, session: URLSession,
                       method: String = "GET")
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
      if let data = data,
         let http = response as? HTTPURLResponse
      {
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

  private func makeURL(port: Int) -> URL {
    guard let url = URL(string: "http://localhost:\(port)/") else {
      XCTFail("Failed to create URL for port \(port)")
      return URL(string: "http://localhost/")
        ?? URL(fileURLWithPath: "/")
    }
    return url
  }

  // MARK: - Tests

  static let allTests = [
    ( "testKeepAliveMultipleRequests",
      testKeepAliveMultipleRequests ),
    ( "testConnectionSurvivesIdlePeriod",
      testConnectionSurvivesIdlePeriod ),
    ( "testConnectionCloseIsHonored",
      testConnectionCloseIsHonored ),
    ( "testIdleConnectionClosedBeforeFirstRequest",
      testIdleConnectionClosedBeforeFirstRequest )
  ]

  func testKeepAliveMultipleRequests() {
    let port    = startServer()
    let session = makeSession()
    defer { session.invalidateAndCancel() }

    let url = makeURL(port: port)

    for i in 0..<5 {
      guard let (_, response) = request(url, session: session)
      else {
        XCTFail("Request \(i) returned no result")
        return
      }
      XCTAssertEqual(response.statusCode, 200,
                     "Request \(i) status")
      let conn =
        response.value(forHTTPHeaderField: "Connection") ?? ""
      XCTAssertNotEqual(conn.lowercased(), "close",
                        "Request \(i) has Connection: close")
    }
  }

  func testConnectionSurvivesIdlePeriod() {
    let port    = startServer()
    let session = makeSession()
    defer { session.invalidateAndCancel() }

    let url = makeURL(port: port)

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

    let url = makeURL(port: port)

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

  /**
   * A connection that receives no data should be closed
   * by the server after `idleTimeout` ms.
   */
  func testIdleConnectionClosedBeforeFirstRequest() {
    let idleTimeoutMS = 2_000
    let port = startServer(idleTimeout: idleTimeoutMS)

    // Open a raw TCP socket, send nothing, and wait for
    // the server to close the idle connection.
    let exp = expectation(description: "connection closed")

    #if canImport(Darwin)
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    #else
    let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #endif
    guard fd >= 0 else {
      XCTFail("Could not create socket")
      return
    }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port   = UInt16(port).bigEndian
    addr.sin_addr   = in_addr(s_addr: UInt32(0x7f000001).bigEndian)
    let rc = withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard rc == 0 else {
      close(fd)
      XCTFail("Could not connect to server")
      return
    }

    DispatchQueue.global().async {
      // Read until the server closes (returns 0 bytes)
      var buf = [ UInt8 ](repeating: 0, count: 1)
      let n = recv(fd, &buf, 1, 0)
      // n <= 0 means server closed or error
      XCTAssertLessThanOrEqual(
        n, 0, "Expected server to close idle connection")
      close(fd)
      exp.fulfill()
    }

    // The server should close within idleTimeout + margin
    waitForExpectations(
      timeout: Double(idleTimeoutMS) / 1000.0 + 3)
  }
}
