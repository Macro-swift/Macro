//
//  PipeliningTests.swift
//  Macro
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

final class PipeliningTests: XCTestCase {

  private final class Ref<T>: @unchecked Sendable {
    var value: T
    init(_ v: T) { value = v }
  }

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  /**
   * Pipelines `count` HTTP/1.1 GETs over a single TCP socket
   * and verifies every response body arrives intact. The
   * server handler ends the response after one EL yield, so
   * `writeAndFlush(.end)` resolves async, exactly the
   * shape that races with `HTTPServerPipelineHandler`.
   */
  func testPipelinedKeepAliveRequestsDoNotRace() throws {
    let bodyBytes = Array("hello-pipelined".utf8)
    let body      = Data(bodyBytes)
    let count     = 32

    // Async-style handler: defer end() to the next tick so
    // the writeAndFlush(.end) resolves on a later EL turn,
    // matching real-world streaming handlers.
    let port = startServer { _, res in
      res.setHeader("Content-Type", "application/octet-stream")
      res.setHeader("Content-Length", body.count)
      res.writeHead(200)
      _ = res.write(Buffer(bodyBytes))
      Macro.process.nextTick(nil) { res.end() }
    }

    let fd = openTCP(toPort: port)
    defer { close(fd) }

    let req = "GET / HTTP/1.1\r\n" +
              "Host: localhost\r\n" +
              "Connection: keep-alive\r\n\r\n"
    let reqBytes = Array(req.utf8)

    // Send all requests back-to-back BEFORE reading any
    // responses, this is what triggers the race.
    for _ in 0..<count {
      try writeAll(fd: fd, bytes: reqBytes)
    }

    // Read until we have parsed `count` complete responses.
    let raw = try readUntilResponses(fd: fd, count: count,
                                      timeoutS: 10)
    let responses = parseHTTPResponses(raw)

    XCTAssertEqual(responses.count, count,
                   "expected \(count) full responses, got \(responses.count)")
    for (i, resp) in responses.enumerated() {
      XCTAssertEqual(resp.status, 200,
                     "response \(i) status \(resp.status)")
      XCTAssertEqual(resp.body, body,
                     "response \(i) body mismatch (\(resp.body.count) bytes)")
    }
  }

  /**
   * Verifies that an early response with `Connection: close` stays open until
   * the request body ends. Closing after the response alone truncates uploads.
   */
  func testConnectionCloseWaitsForRequestEnd() throws {
    let bodyBytes = Array("early-response".utf8)
    let body      = Data(bodyBytes)
    let port = startServer { _, res in
      res.setHeader("Connection", "close")
      res.setHeader("Content-Length", body.count)
      res.writeHead(200)
      _ = res.write(Buffer(bodyBytes))
      res.end()
    }

    let fd = openTCP(toPort: port)
    defer { close(fd) }

    let request = "POST / HTTP/1.1\r\n" +
                  "Host: localhost\r\n" +
                  "Content-Length: 4\r\n" +
                  "Connection: close\r\n\r\n"
    try writeAll(fd: fd, bytes: Array(request.utf8))

    let raw = try readUntilResponses(fd: fd, count: 1, timeoutS: 5)
    let responses = parseHTTPResponses(raw)
    XCTAssertEqual(responses.count, 1)
    guard let response = responses.first else {
      XCTFail("expected an early response")
      return
    }
    XCTAssertEqual(response.status, 200)
    XCTAssertEqual(response.body, body)

    let closedEarly = try isSocketClosed(fd: fd, timeoutMS: 200)
    XCTAssertFalse(closedEarly,
                   "server closed before request body completed")

    try writeAll(fd: fd, bytes: Array("body".utf8))
    let closedAfterBody = try isSocketClosed(fd: fd, timeoutMS: 2_000)
    XCTAssertTrue(closedAfterBody,
                  "server did not close after request body completed")
  }

  /**
   * Verifies that `Connection: close` also closes when the request ends before
   * the application writes its response.
   */
  func testConnectionClosesAfterDelayedResponse() throws {
    let bodyBytes = Array("delayed-response".utf8)
    let body      = Data(bodyBytes)
    let port = startServer { req, res in
      req.onEnd {
        res.setHeader("Connection", "close")
        res.setHeader("Content-Length", body.count)
        res.writeHead(200)
        _ = res.write(Buffer(bodyBytes))
        res.end()
      }
    }

    let fd = openTCP(toPort: port)
    defer { close(fd) }

    let request = "GET / HTTP/1.1\r\n" +
                  "Host: localhost\r\n" +
                  "Connection: close\r\n\r\n"
    try writeAll(fd: fd, bytes: Array(request.utf8))

    let raw = try readUntilResponses(fd: fd, count: 1, timeoutS: 5)
    let responses = parseHTTPResponses(raw)
    XCTAssertEqual(responses.count, 1)
    guard let response = responses.first else {
      XCTFail("expected a delayed response")
      return
    }
    XCTAssertEqual(response.status, 200)
    XCTAssertEqual(response.body, body)

    let closed = try isSocketClosed(fd: fd, timeoutMS: 2_000)
    XCTAssertTrue(closed,
                  "server did not close after delayed response completed")
  }

  func testHTTP10DefaultConnectionCloses() throws {
    let bodyBytes = Array("http-1.0-close".utf8)
    let body      = Data(bodyBytes)
    let port = startServer { _, res in
      res.setHeader("Content-Length", body.count)
      res.writeHead(200)
      _ = res.write(Buffer(bodyBytes))
      res.end()
    }

    let fd = openTCP(toPort: port)
    defer { close(fd) }

    let request = "GET / HTTP/1.0\r\n" +
                  "Host: localhost\r\n\r\n"
    try writeAll(fd: fd, bytes: Array(request.utf8))

    let raw = try readUntilResponses(fd: fd, count: 1, timeoutS: 5)
    let responses = parseHTTPResponses(raw)
    XCTAssertEqual(responses.count, 1)
    XCTAssertEqual(responses.first?.body, body)

    let closed = try isSocketClosed(fd: fd, timeoutMS: 2_000)
    XCTAssertTrue(closed, "HTTP/1.0 connection remained open")
  }

  func testHTTP10KeepAliveConnectionCanBeReused() throws {
    let bodyBytes = Array("http-1.0-keep-alive".utf8)
    let body      = Data(bodyBytes)
    let port = startServer { _, res in
      res.setHeader("Content-Length", body.count)
      res.writeHead(200)
      _ = res.write(Buffer(bodyBytes))
      res.end()
    }

    let fd = openTCP(toPort: port)
    defer { close(fd) }

    let request = "GET / HTTP/1.0\r\n" +
                  "Host: localhost\r\n" +
                  "Connection: keep-alive\r\n\r\n"
    let bytes = Array(request.utf8)

    try writeAll(fd: fd, bytes: bytes)
    let firstRaw = try readUntilResponses(fd: fd, count: 1, timeoutS: 5)
    let first = parseHTTPResponses(firstRaw)
    XCTAssertEqual(first.count, 1)
    XCTAssertEqual(first.first?.body, body)

    let closed = try isSocketClosed(fd: fd, timeoutMS: 100)
    XCTAssertFalse(closed, "HTTP/1.0 keep-alive connection was closed")

    try writeAll(fd: fd, bytes: bytes)
    let secondRaw = try readUntilResponses(fd: fd, count: 1, timeoutS: 5)
    let second = parseHTTPResponses(secondRaw)
    XCTAssertEqual(second.count, 1)
    XCTAssertEqual(second.first?.body, body)
  }

  // MARK: - Server scaffolding (mirrors KeepAliveTests)

  private func startServer(host: String = "127.0.0.1",
                           idleTimeout: Int = 5_000,
                           handler: @escaping
                             (IncomingMessage, ServerResponse) -> Void)
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

  // MARK: - Raw TCP helpers

  private func openTCP(toPort port: Int) -> Int32 {
    #if canImport(Darwin)
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    #else
    let fd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
    #endif
    XCTAssertGreaterThanOrEqual(fd, 0, "socket()")
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port   = UInt16(port).bigEndian
    addr.sin_addr   = in_addr(s_addr: UInt32(0x7f000001).bigEndian)
    let rc = withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    XCTAssertEqual(rc, 0, "connect()")
    return fd
  }

  private enum IOError: Error { case writeFailed, readFailed, eof, timeout }

  private func writeAll(fd: Int32, bytes: [ UInt8 ]) throws {
    var sent = 0
    while sent < bytes.count {
      let n = bytes.withUnsafeBufferPointer { p -> Int in
        guard let base = p.baseAddress else { return -1 }
        #if canImport(Darwin)
        return send(fd, base + sent, bytes.count - sent, 0)
        #else
        return send(fd, base + sent, bytes.count - sent, Int32(MSG_NOSIGNAL))
        #endif
      }
      if n <= 0 { throw IOError.writeFailed }
      sent += n
    }
  }

  private func waitForReadable(fd: Int32, timeoutMS: Int32) throws -> Bool {
    var descriptor = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
    while true {
      let result = poll(&descriptor, 1, timeoutMS)
      if result > 0 { return true }
      if result == 0 { return false }
      if errno != EINTR { throw IOError.readFailed }
    }
  }

  private func isSocketClosed(fd: Int32, timeoutMS: Int32) throws -> Bool {
    let readable = try waitForReadable(fd: fd, timeoutMS: timeoutMS)
    guard readable else { return false }
    var byte: UInt8 = 0
    let result = recv(fd, &byte, 1, Int32(MSG_PEEK))
    if result == 0 { return true }
    if result < 0 { throw IOError.readFailed }
    return false
  }

  private func readUntilResponses(fd: Int32, count: Int,
                                   timeoutS: Double) throws
                -> Data
  {
    let deadline = Date().addingTimeInterval(timeoutS)
    var collected = Data()
    var seen      = 0
    var buf       = [ UInt8 ](repeating: 0, count: 16 * 1024)
    while seen < count {
      let remaining = deadline.timeIntervalSinceNow
      if remaining <= 0 { throw IOError.timeout }
      let timeoutMS = Int32(max(1, remaining * 1_000))
      guard try waitForReadable(fd: fd, timeoutMS: timeoutMS) else {
        throw IOError.timeout
      }
      let cap = buf.count
      let n = buf.withUnsafeMutableBufferPointer { p -> Int in
        guard let base = p.baseAddress else { return -1 }
        return recv(fd, base, cap, 0)
      }
      if n == 0 { throw IOError.eof }
      if n < 0  { throw IOError.readFailed }
      collected.append(buf, count: n)
      seen = countCompletedResponses(in: collected)
    }
    return collected
  }

  /// Returns how many complete HTTP responses (status line +
  /// headers + Content-Length-sized body) are visible in
  /// `data`. Assumes responses use Content-Length (we set it
  /// in the handler).
  private func countCompletedResponses(in data: Data) -> Int {
    var pos   = 0
    var count = 0
    let bytes = [ UInt8 ](data)
    while pos < bytes.count {
      guard let headerEnd = findCRLFCRLF(bytes, from: pos)
      else { return count }
      let headerSlice = bytes[pos..<headerEnd]
      let length = parseContentLength(in: headerSlice) ?? 0
      let bodyStart = headerEnd + 4
      let bodyEnd   = bodyStart + length
      if bodyEnd > bytes.count { return count }
      count += 1
      pos = bodyEnd
    }
    return count
  }

  private func findCRLFCRLF(_ bytes: [ UInt8 ], from: Int) -> Int? {
    if bytes.count < 4 { return nil }
    var i = from
    while i + 3 < bytes.count {
      if bytes[i] == 0x0d, bytes[i+1] == 0x0a,
         bytes[i+2] == 0x0d, bytes[i+3] == 0x0a
      { return i }
      i += 1
    }
    return nil
  }

  private func parseContentLength(in slice: ArraySlice<UInt8>) -> Int? {
    guard let s = String(bytes: slice, encoding: .utf8)
    else { return nil }
    for line in s.split(separator: "\r\n") {
      let parts = line.split(separator: ":", maxSplits: 1)
      guard parts.count == 2 else { continue }
      if parts[0].trimmingCharacters(in: .whitespaces)
                 .lowercased() == "content-length"
      {
        return Int(parts[1].trimmingCharacters(in: .whitespaces))
      }
    }
    return nil
  }

  struct ParsedResponse { let status: Int; let body: Data }

  private func parseHTTPResponses(_ data: Data) -> [ ParsedResponse ] {
    var out   = [ ParsedResponse ]()
    var pos   = 0
    let bytes = [ UInt8 ](data)
    while pos < bytes.count {
      guard let headerEnd = findCRLFCRLF(bytes, from: pos)
      else { break }
      let headerSlice = bytes[pos..<headerEnd]
      let header = String(bytes: headerSlice, encoding: .utf8) ?? ""
      let firstLine = header.split(separator: "\r\n",
                                   maxSplits: 1).first ?? ""
      let parts = firstLine.split(separator: " ", maxSplits: 2)
      let status = parts.count >= 2 ? Int(parts[1]) ?? 0 : 0
      let length = parseContentLength(in: headerSlice) ?? 0
      let bodyStart = headerEnd + 4
      let bodyEnd   = bodyStart + length
      if bodyEnd > bytes.count { break }
      let body = Data(bytes[bodyStart..<bodyEnd])
      out.append(ParsedResponse(status: status, body: body))
      pos = bodyEnd
    }
    return out
  }

  static let allTests = [
    ( "testPipelinedKeepAliveRequestsDoNotRace",
      testPipelinedKeepAliveRequestsDoNotRace ),
    ( "testConnectionCloseWaitsForRequestEnd",
      testConnectionCloseWaitsForRequestEnd ),
    ( "testConnectionClosesAfterDelayedResponse",
      testConnectionClosesAfterDelayedResponse ),
    ( "testHTTP10DefaultConnectionCloses",
      testHTTP10DefaultConnectionCloses ),
    ( "testHTTP10KeepAliveConnectionCanBeReused",
      testHTTP10KeepAliveConnectionCanBeReused )
  ]
}
