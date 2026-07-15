import XCTest
import Foundation
@testable import MacroCore
@testable import fs

final class WriteFileAtomicTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  private func tempPath() -> String {
    NSTemporaryDirectory() + "wfa-\(UUID().uuidString).txt"
  }

  private func inode(_ path: String) -> Int? {
    let attrs = try? FileManager.default.attributesOfItem(atPath: path)
    return attrs?[.systemFileNumber] as? Int
  }

  func testWritesContentBothModes() throws {
    let path = tempPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    try fs.writeFileSync(path, "hello")               // atomic default
    XCTAssertEqual(fs.readFileSync(path, .utf8), "hello")

    try fs.writeFileSync(path, "world", atomic: false)
    XCTAssertEqual(fs.readFileSync(path, .utf8), "world")
  }

  func testAtomicReplacesInodeInPlaceKeepsIt() throws {
    let path = tempPath()
    defer { try? FileManager.default.removeItem(atPath: path) }

    try fs.writeFileSync(path, "v1", atomic: false)   // create in place
    let original = inode(path)
    XCTAssertNotNil(original)

    // An in-place write keeps the same inode.
    try fs.writeFileSync(path, "v2", atomic: false)
    XCTAssertEqual(inode(path), original)

    // An atomic write (temp file + rename) gives the path a new inode.
    try fs.writeFileSync(path, "v3", atomic: true)
    XCTAssertNotEqual(inode(path), original)
    XCTAssertEqual(fs.readFileSync(path, .utf8), "v3")
  }
}
