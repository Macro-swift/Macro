//
//  WebSocketTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2025 ZeeZide GmbH. All rights reserved.
//

import XCTest
@testable import ws
@testable import MacroCore

final class WebSocketTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - ReadyState Tests

  func testReadyStateValues() {
    XCTAssertEqual(WebSocket.ReadyState.connecting.rawValue, 0)
    XCTAssertEqual(WebSocket.ReadyState.open.rawValue,       1)
    XCTAssertEqual(WebSocket.ReadyState.closing.rawValue,    2)
    XCTAssertEqual(WebSocket.ReadyState.closed.rawValue,     3)
  }

  func testInitialReadyState() {
    // A WebSocket created without a channel should be in connecting state
    let ws = WebSocket(nil)
    XCTAssertEqual(ws.readyState, .connecting)
    XCTAssertFalse(ws.isConnected)
  }

  // MARK: - Server Creation Tests

  func testServerCreation() {
    let expectation = self.expectation(description: "Server listening")

    let server = WebSocket.Server(port: 0)
    server.onListening { srv in
      XCTAssertTrue(srv.listening)
      XCTAssertNotNil(srv.listenAddresses.first?.port)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 5)
    XCTAssertTrue(server.listening)
  }

  func testServerListenAddress() {
    let expectation = self.expectation(description: "Server listening")
    var actualPort: Int?

    let server = WebSocket.Server(port: 0)
    server.onListening { srv in
      actualPort = srv.listenAddresses.first?.port
      expectation.fulfill()
    }

    waitForExpectations(timeout: 5)

    XCTAssertNotNil(actualPort)
    if let port = actualPort {
      XCTAssertGreaterThan(port, 0)
    }
  }

  // MARK: - Error Tests

  func testInvalidURL() {
    let errorReceived = expectation(description: "Error received")

    let client = WebSocket("not a valid url")
    client.onError { error in
      // URL might be parsed as a URL without scheme, so we accept either error
      if case WebSocket.WebSocketError.invalidURL = error {
        errorReceived.fulfill()
      }
      else if case WebSocket.WebSocketError.unsupportedURLScheme = error {
        errorReceived.fulfill()
      }
      else {
        XCTFail("Unexpected error type: \(error)")
      }
    }

    waitForExpectations(timeout: 2)
  }

  func testSendWhenNotConnected() {
    let errorReceived = expectation(description: "Error received")

    let client = WebSocket(nil)
    client.onError { error in
      if case WebSocket.WebSocketError.connectionNotOpen = error {
        errorReceived.fulfill()
      }
    }

    client.send(text: "This should fail")

    waitForExpectations(timeout: 2)
  }

  func testPingWhenNotConnected() {
    let errorReceived = expectation(description: "Error received")

    let client = WebSocket(nil)
    client.onError { error in
      if case WebSocket.WebSocketError.connectionNotOpen = error {
        errorReceived.fulfill()
      }
    }

    client.ping()

    waitForExpectations(timeout: 2)
  }

  func testCloseWhenNotConnected() {
    // Closing when not connected should be a no-op, not an error
    let client = WebSocket(nil)
    XCTAssertEqual(client.readyState, .connecting)

    client.close()
    XCTAssertEqual(client.readyState, .closed)
  }

  func testTerminateWhenNotConnected() {
    let client = WebSocket(nil)
    XCTAssertEqual(client.readyState, .connecting)

    client.terminate()
    XCTAssertEqual(client.readyState, .closed)
  }

  func testDoubleClose() {
    let client = WebSocket(nil)
    client.close()
    XCTAssertEqual(client.readyState, .closed)

    // Second close should be a no-op
    client.close()
    XCTAssertEqual(client.readyState, .closed)
  }

  func testDoubleTerminate() {
    let client = WebSocket(nil)
    client.terminate()
    XCTAssertEqual(client.readyState, .closed)

    // Second terminate should be a no-op
    client.terminate()
    XCTAssertEqual(client.readyState, .closed)
  }

  // MARK: - All Tests

  static var allTests = [
    ( "testReadyStateValues",        testReadyStateValues        ),
    ( "testInitialReadyState",       testInitialReadyState       ),
    ( "testServerCreation",          testServerCreation          ),
    ( "testServerListenAddress",     testServerListenAddress     ),
    ( "testInvalidURL",              testInvalidURL              ),
    ( "testSendWhenNotConnected",    testSendWhenNotConnected    ),
    ( "testPingWhenNotConnected",    testPingWhenNotConnected    ),
    ( "testCloseWhenNotConnected",   testCloseWhenNotConnected   ),
    ( "testTerminateWhenNotConnected", testTerminateWhenNotConnected ),
    ( "testDoubleClose",             testDoubleClose             ),
    ( "testDoubleTerminate",         testDoubleTerminate         ),
  ]
}
