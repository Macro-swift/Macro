//
//  NextTickTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import NIOCore
import NIOPosix
@testable import MacroCore

final class NextTickTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - nextTick

  nonisolated func testNextTickOnEventLoop() throws {
    let loop = MacroCore.shared.eventLoopGroup.next()
    let promise = loop.makePromise(of: Void.self)
    var x = 10

    nextTick(on: loop) {
      XCTAssertNotNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(loop.inEventLoop)
      x += 12
      promise.succeed(())
    }
    try promise.futureResult.wait()
    XCTAssertEqual(x, 22)
  }

  // MARK: - setTimeout

  nonisolated func testSetTimeoutOnEventLoop() throws {
    let loop = MacroCore.shared.eventLoopGroup.next()
    let promise = loop.makePromise(of: Void.self)

    setTimeout(on: loop, 10) {
      XCTAssertNotNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(loop.inEventLoop)
      promise.succeed(())
    }
    try promise.futureResult.wait()
  }
}
