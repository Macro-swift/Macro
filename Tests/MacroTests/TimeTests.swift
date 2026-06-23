//
//  TimeTests.swift
//  MacroTests
//
//  Tests for the byte-level date parsers/formatters in xsys/time.swift.
//

import XCTest
@testable import xsys

final class TimeTests: XCTestCase {

  func testISO8601FullDateTime() throws {
    let tm = try XCTUnwrap(
      xsys.struct_tm(iso8601String: "2026-05-17T12:34:56Z")
    )
    XCTAssertEqual(tm.tm_year, 2026 - 1900)
    XCTAssertEqual(tm.tm_mon,  4) // 0-based: May
    XCTAssertEqual(tm.tm_mday, 17)
    XCTAssertEqual(tm.tm_hour, 12)
    XCTAssertEqual(tm.tm_min,  34)
    XCTAssertEqual(tm.tm_sec,  56)
  }

  func testISO8601DateOnly() throws {
    let tm = try XCTUnwrap(xsys.struct_tm(iso8601String: "2026-01-01"))
    XCTAssertEqual(tm.tm_year, 2026 - 1900)
    XCTAssertEqual(tm.tm_mon,  0) // January
    XCTAssertEqual(tm.tm_mday, 1)
    XCTAssertEqual(tm.tm_hour, 0)
    XCTAssertEqual(tm.tm_min,  0)
    XCTAssertEqual(tm.tm_sec,  0)
  }

  func testISO8601SpaceSeparator() throws {
    let tm = try XCTUnwrap(xsys.struct_tm(iso8601String: "2026-12-31 23:59:59"))
    XCTAssertEqual(tm.tm_mon,  11) // December
    XCTAssertEqual(tm.tm_mday, 31)
    XCTAssertEqual(tm.tm_hour, 23)
    XCTAssertEqual(tm.tm_sec,  59)
  }

  func testISO8601RoundTrip() throws {
    let s  = "2026-05-17T12:34:56Z"
    let tm = try XCTUnwrap(xsys.struct_tm(iso8601String: s))
    XCTAssertEqual(tm.iso8601String, s)
  }

  func testISO8601RejectsBadInput() {
    XCTAssertNil(xsys.struct_tm(iso8601String: ""))
    XCTAssertNil(xsys.struct_tm(iso8601String: "2026/05/17"))
    XCTAssertNil(xsys.struct_tm(iso8601String: "2026-13-01")) // bad month
    XCTAssertNil(xsys.struct_tm(iso8601String: "2026-05-32")) // bad day
    XCTAssertNil(xsys.struct_tm(iso8601String: "not-a-date"))
    XCTAssertNil(xsys.struct_tm(iso8601String: "2026-05"))    // too short
  }
}
