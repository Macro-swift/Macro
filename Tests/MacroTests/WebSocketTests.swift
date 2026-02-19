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

  // MARK: - Integration Tests

  private func startServer(
    onConnection: @escaping ( WebSocket ) -> Void,
    onListening:  @escaping ( Int ) -> Void
  ) -> WebSocket.Server
  {
    let server = WebSocket.Server(port: 0)
    server.onConnection(execute: onConnection)
    server.onListening { srv in
      guard let port = srv.listenAddresses.first?.port
      else {
        XCTFail("Server has no listen address")
        return
      }
      onListening(port)
    }
    return server
  }

  func testClientServerTextMessage() {
    let connected       = expectation(description: "Connected")
    let messageReceived = expectation(description: "Message received")

    let server = startServer(
      onConnection: { ws in
        ws.onText { text in
          XCTAssertEqual(text, "Hello Server")
          ws.send(text: "Hello Client")
        }
      },
      onListening: { port in
        let client = WebSocket("ws://localhost:\(port)/")
        client.onOpen { ws in
          connected.fulfill()
          ws.send(text: "Hello Server")
        }
        client.onText { text in
          XCTAssertEqual(text, "Hello Client")
          messageReceived.fulfill()
        }
      }
    )
    _ = server

    waitForExpectations(timeout: 5)
  }

  func testClientServerEcho() {
    let allReceived = expectation(description: "All echoed")
    let messages    = [ "one", "two", "three" ]

    let server = startServer(
      onConnection: { ws in
        ws.onText { text in
          ws.send(text: text)
        }
      },
      onListening: { port in
        var received = [ String ]()
        let client = WebSocket("ws://localhost:\(port)/")
        client.onOpen { ws in
          for msg in messages { ws.send(text: msg) }
        }
        client.onText { text in
          received.append(text)
          if received.count == messages.count {
            XCTAssertEqual(received, messages)
            allReceived.fulfill()
          }
        }
      }
    )
    _ = server

    waitForExpectations(timeout: 5)
  }

  func testClientServerClose() {
    let clientClosed = expectation(description: "Client closed")
    let serverClosed = expectation(description: "Server closed")

    let server = startServer(
      onConnection: { ws in
        ws.onText { _ in
          ws.close()
        }
        ws.onClose {
          serverClosed.fulfill()
        }
      },
      onListening: { port in
        let client = WebSocket("ws://localhost:\(port)/")
        client.onOpen { ws in
          ws.send(text: "trigger close")
        }
        client.onClose {
          clientClosed.fulfill()
        }
      }
    )
    _ = server

    waitForExpectations(timeout: 5)
  }

  func testClientServerPingPong() {
    let pongReceived = expectation(description: "Pong received")

    let server = startServer(
      onConnection: { _ in },
      onListening: { port in
        let client = WebSocket("ws://localhost:\(port)/")
        client.onOpen { ws in
          ws.ping()
        }
        client.onPong {
          pongReceived.fulfill()
        }
      }
    )
    _ = server

    waitForExpectations(timeout: 5)
  }

  func testServerSendsOnConnection() {
    let received = expectation(description: "Greeting received")

    let server = startServer(
      onConnection: { ws in
        ws.send(text: "Welcome!")
      },
      onListening: { port in
        let client = WebSocket("ws://localhost:\(port)/")
        client.onText { text in
          XCTAssertEqual(text, "Welcome!")
          received.fulfill()
        }
      }
    )
    _ = server

    waitForExpectations(timeout: 5)
  }

  // MARK: - All Tests

  static var allTests = [
    ( "testReadyStateValues",          testReadyStateValues          ),
    ( "testInitialReadyState",         testInitialReadyState         ),
    ( "testServerCreation",            testServerCreation            ),
    ( "testServerListenAddress",       testServerListenAddress       ),
    ( "testInvalidURL",                testInvalidURL                ),
    ( "testSendWhenNotConnected",      testSendWhenNotConnected      ),
    ( "testPingWhenNotConnected",      testPingWhenNotConnected      ),
    ( "testCloseWhenNotConnected",     testCloseWhenNotConnected     ),
    ( "testTerminateWhenNotConnected", testTerminateWhenNotConnected ),
    ( "testDoubleClose",               testDoubleClose               ),
    ( "testDoubleTerminate",           testDoubleTerminate           ),
    ( "testClientServerTextMessage",   testClientServerTextMessage   ),
    ( "testClientServerEcho",          testClientServerEcho          ),
    ( "testClientServerClose",         testClientServerClose         ),
    ( "testClientServerPingPong",      testClientServerPingPong      ),
    ( "testServerSendsOnConnection",   testServerSendsOnConnection   ),
  ]
}
