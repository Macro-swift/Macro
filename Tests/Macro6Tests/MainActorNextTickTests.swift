//
//  MainActorNextTickTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import NIOCore
import NIOPosix
import Macro6
@testable import MacroCore

private func assertOnMainActor() {
  #if canImport(Darwin)
  XCTAssertTrue(Thread.isMainThread)
  #else
  MainActor.assertIsolated()
  #endif
}

// Note: Tests are `nonisolated` because `@MainActor` on XCTestCase
// subclasses doesn't work with XCTest test discovery on Linux.
final class MainActorNextTickTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - @MainActor nextTick

  nonisolated func testMainActorNextTick() async {
    await withCheckedContinuation { continuation in
      nextTick { @MainActor in
        XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
        assertOnMainActor()
        continuation.resume()
      }
    }
  }

  nonisolated func testMainActorNextTickOnEventLoop() async {
    let loop = MacroCore.shared.eventLoopGroup.next()
    await withCheckedContinuation { continuation in
      nextTick(on: loop) { @MainActor in
        XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
        assertOnMainActor()
        continuation.resume()
      }
    }
  }

  // MARK: - @MainActor setTimeout

  nonisolated func testMainActorSetTimeout() async {
    await withCheckedContinuation { continuation in
      setTimeout(10) { @MainActor in
        XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
        assertOnMainActor()
        continuation.resume()
      }
    }
  }

  nonisolated func testMainActorSetTimeoutOnEventLoop() async {
    let loop = MacroCore.shared.eventLoopGroup.next()
    await withCheckedContinuation { continuation in
      setTimeout(on: loop, 10) { @MainActor in
        XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
        assertOnMainActor()
        continuation.resume()
      }
    }
  }
}
