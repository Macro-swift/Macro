//
//  SmallBodyEndTests.swift
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

final class SmallBodyEndTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  func testEndWithBodyBelowHighWaterMark() {
    // Make sure this gets flushed.
    let body = String(repeating: "x", count: 10)
    let port = startServer(body: body)
    XCTAssertEqual(fetch(port: port), body)
  }

  func testEndWithBodyAtHighWaterMark() {
    let body = String(repeating: "x", count: 4096)
    let port = startServer(body: body)
    XCTAssertEqual(fetch(port: port)?.count, 4096)
  }

  func testEndWithEmptyBody() {
    let port = startServer(body: "")
    XCTAssertEqual(fetch(port: port)?.count, 0)
  }

  // MARK: - Helpers

  private func startServer(body: String) -> Int {
    final class Ref<T>: @unchecked Sendable { // make T Sendable
      var value: T
      init(_ v: T) { value = v }
    }

    let listenExp = expectation(description: "listening")
    let portRef   = Ref(0)

    let server = http.createServer { _, res in
      res.writeHead(200, [ "Content-Type": "text/plain" ])
      res.end(body)
    }
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

  /// Fetches the body using Macro's own HTTP client. A response that
  /// is never terminated fails on the expectation timeout instead of
  /// hanging the test: that timeout is what the bug trips.
  private func fetch(port: Int, timeout: TimeInterval = 3) -> String? {
    final class Ref<T>: @unchecked Sendable { // make T Sendable
      var value: T
      init(_ v: T) { value = v }
    }

    let exp = expectation(description: "GET :\(port)")
    exp.assertForOverFulfill = false // an error and an end can both land
    let body   = Ref("")
    let didEnd = Ref(false)

    let options = http.ClientRequestOptions(
      host    : "127.0.0.1",
      port    : port,
      path    : "/",
      timeout : Int(timeout * 1000)
    )

    let req = http.get(options: options) { res in
      XCTAssertEqual(res.statusCode, 200)
      res.onError { error in
        XCTFail("Response body never completed: \(error)")
        exp.fulfill()
      }
      res | concat { buffer in
        body.value = (try? buffer.toString()) ?? ""
      }
      res.onEnd {
        didEnd.value = true
        exp.fulfill()
      }
    }
    req.onError { error in
      XCTFail("Request never completed: \(error)")
      exp.fulfill()
    }

    waitForExpectations(timeout: timeout + 5)
    return didEnd.value ? body.value : nil
  }

  static let allTests = [
    ( "testEndWithBodyBelowHighWaterMark" , testEndWithBodyBelowHighWaterMark ),
    ( "testEndWithBodyAtHighWaterMark"    , testEndWithBodyAtHighWaterMark    ),
    ( "testEndWithEmptyBody"              , testEndWithEmptyBody )
  ]
}
