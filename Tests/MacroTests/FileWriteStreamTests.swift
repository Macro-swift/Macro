import XCTest
import struct Foundation.Data
import struct Foundation.URL
import struct Foundation.UUID
import NIOConcurrencyHelpers
@testable import MacroCore
@testable import fs

final class FileWriteStreamTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  /// `end()` with no buffered or in-flight writes must close the file and
  /// fire `onFinish` synchronously via `destroy()`.
  func testEndOnEmptyStreamFiresFinish() throws {
    let path = Self.tempPath(prefix: "fws-empty")
    addTeardownBlock { try? Self.remove(path) }

    let exp  = expectation(description: "finish")
    let loop = MacroCore.shared.fallbackEventLoop()
    loop.execute {
      let stream = fs.createWriteStream(on: loop, path)
      _ = stream.onFinish { exp.fulfill() }
      stream.end()
    }
    waitForExpectations(timeout: 3)
  }

  /// Regression for the bug where `_handleAllPendingDone` looked at
  /// `state == .ending` (a state nothing ever set), so `onFinish` never
  /// fired once `end()` was called with writes still in flight.
  func testEndWithPendingWritesFiresFinish() throws {
    let path = Self.tempPath(prefix: "fws-pending")
    addTeardownBlock { try? Self.remove(path) }

    let exp  = expectation(description: "finish")
    let loop = MacroCore.shared.fallbackEventLoop()
    loop.execute {
      let stream = fs.createWriteStream(on: loop, path)
      _ = stream.onFinish { exp.fulfill() }
      // Issue several writes back to back, then `end()` -- the first write
      // also kicks off the (async) file open, so all of these sit in the
      // buffer / in-flight when `end()` is called.
      let chunk = Buffer([ UInt8 ]( repeating: 0x41, count: 4096 ))
      for _ in 0..<8 { _ = stream.write(chunk, whenDone: {}) }
      stream.end()
    }
    waitForExpectations(timeout: 5)

    let onDisk = try Data(contentsOf: URL(fileURLWithPath: path))
    XCTAssertEqual(onDisk.count, 4096 * 8)
  }

  /// Regression for the bug where `close()` (called from `destroy()`)
  /// invoked `_clearListeners()`, wiping `finishListeners` before
  /// `destroy()` got to emit them. Verifies that close fires before finish
  /// and finish still fires.
  func testCloseListenersFireBeforeFinish() throws {
    let path = Self.tempPath(prefix: "fws-order")
    addTeardownBlock { try? Self.remove(path) }

    let exp   = expectation(description: "finish")
    let order = NIOLockedValueBox([ String ]())
    let loop  = MacroCore.shared.fallbackEventLoop()
    loop.execute {
      let stream = fs.createWriteStream(on: loop, path)
      stream.closeListeners += {
        order.withLockedValue { $0.append("close") }
      }
      _ = stream.onFinish {
        order.withLockedValue { $0.append("finish") }
        exp.fulfill()
      }
      _ = stream.write(Buffer("hi"), whenDone: {})
      stream.end()
    }
    waitForExpectations(timeout: 3)

    XCTAssertEqual(order.withLockedValue { $0 }, [ "close", "finish" ])
  }

  /// Regression for the bug where each `_write` issued while still in
  /// `.pending` state kicked off another `open()`, racing to assign the
  /// file handle and tripping `assert(self.fileHandle == nil)` in the
  /// second open's completion.
  func testMultipleWritesBeforeOpenDoNotDoubleOpen() throws {
    let path = Self.tempPath(prefix: "fws-doubleopen")
    addTeardownBlock { try? Self.remove(path) }

    let exp  = expectation(description: "finish")
    let loop = MacroCore.shared.fallbackEventLoop()
    loop.execute {
      let stream = fs.createWriteStream(on: loop, path)
      _ = stream.onFinish { exp.fulfill() }
      for i in 0..<16 {
        _ = stream.write(Buffer("chunk-\(i);"), whenDone: {})
      }
      stream.end()
    }
    waitForExpectations(timeout: 5)

    let onDisk = try String(
      contentsOf: URL(fileURLWithPath: path), encoding: .utf8
    )
    let expected = (0..<16).map { "chunk-\($0);" }.joined()
    XCTAssertEqual(onDisk, expected)
  }

  // MARK: - Helpers

  private static func tempPath(prefix: String) -> String {
    NSTemporaryDirectory() + "\(prefix)-\(UUID().uuidString)"
  }

  private static func remove(_ path: String) throws {
    try FileManager.default.removeItem(atPath: path)
  }

  static let allTests = [
    ( "testEndOnEmptyStreamFiresFinish"   , testEndOnEmptyStreamFiresFinish   ),
    ("testEndWithPendingWritesFiresFinish",
     testEndWithPendingWritesFiresFinish ),
    ( "testCloseListenersFireBeforeFinish", testCloseListenersFireBeforeFinish),
    ("testMultipleWritesBeforeOpenDoNotDoubleOpen",
     testMultipleWritesBeforeOpenDoNotDoubleOpen )
  ]
}
