//
//  NextTickTests.swift
//  MacroTests
//
//  Created by Helge Hess.
//  Copyright (C) 2020-2026 ZeeZide GmbH. All rights reserved.
//

import XCTest
@testable import MacroCore

final class NextTickTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  // MARK: - nextTick

  func testNextTick() {
    let exp = expectation(description: "nextTick fires")
    nextTick { exp.fulfill() }
    waitForExpectations(timeout: 2)
  }

  func testNextTickOnEventLoop() {
    let exp  = expectation(description: "nextTick fires on loop")
    let loop = MacroCore.shared.eventLoopGroup.next()
    nextTick(on: loop) {
      XCTAssertTrue(loop.inEventLoop)
      exp.fulfill()
    }
    waitForExpectations(timeout: 2)
  }

  func testNextTickOrder() {
    var order = [ Int ]()
    let exp = expectation(description: "both ticks fire")
    let loop = MacroCore.shared.eventLoopGroup.next()
    nextTick(on: loop) {
      order.append(1)
    }
    nextTick(on: loop) {
      order.append(2)
      XCTAssertEqual(order, [ 1, 2 ])
      exp.fulfill()
    }
    waitForExpectations(timeout: 2)
  }

  // MARK: - setTimeout

  func testSetTimeout() {
    let exp = expectation(description: "setTimeout fires")
    setTimeout(10) { exp.fulfill() }
    waitForExpectations(timeout: 2)
  }

  func testSetTimeoutOnEventLoop() {
    let exp  = expectation(description: "setTimeout fires on loop")
    let loop = MacroCore.shared.eventLoopGroup.next()
    setTimeout(on: loop, 10) {
      XCTAssertTrue(loop.inEventLoop)
      exp.fulfill()
    }
    waitForExpectations(timeout: 2)
  }

  static let allTests = [
    ( "testNextTick"              , testNextTick              ),
    ( "testNextTickOnEventLoop"   , testNextTickOnEventLoop   ),
    ( "testNextTickOrder"         , testNextTickOrder         ),
    ( "testSetTimeout"            , testSetTimeout            ),
    ( "testSetTimeoutOnEventLoop" , testSetTimeoutOnEventLoop )
  ]
}
