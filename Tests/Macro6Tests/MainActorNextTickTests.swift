//
//  MainActorNextTickTests.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
import NIOPosix
import Macro6
@testable import MacroCore

@MainActor
final class MainActorNextTickTests: XCTestCase {
  // We test

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - @MainActor nextTick

  func testMainActorNextTick() {
    XCTAssertTrue(Thread.isMainThread)
    let exp = expectation(description: "MainActor nextTick fires")
    nextTick { @MainActor in // isolate closure to main actor
      XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(Thread.isMainThread)
      exp.fulfill()
    }
    waitForExpectations(timeout: 2)
  }

  func testMainActorNextTickOnEventLoop() {
    XCTAssertTrue(Thread.isMainThread)
    let exp  = expectation(description: "MainActor nextTick on loop")
    let loop = MacroCore.shared.eventLoopGroup.next()
    nextTick(on: loop) { @MainActor in // isolate closure to main actor
      XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(Thread.isMainThread)
      exp.fulfill()      
    }
    waitForExpectations(timeout: 2)
  }

  // MARK: - @MainActor setTimeout

  func testMainActorSetTimeout() {
    let exp = expectation(description: "MainActor setTimeout fires")
    setTimeout(10) { @MainActor in 
      XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(Thread.isMainThread)
      exp.fulfill()      
    }
    waitForExpectations(timeout: 2)
  }

  func testMainActorSetTimeoutOnEventLoop() {
    let exp  = expectation(description: "MainActor setTimeout on loop")
    let loop = MacroCore.shared.eventLoopGroup.next()
    setTimeout(on: loop, 10) { @MainActor in
      XCTAssertNil(MultiThreadedEventLoopGroup.currentEventLoop)
      XCTAssertTrue(Thread.isMainThread)
      exp.fulfill()      
    }
    waitForExpectations(timeout: 2)
  }
}
