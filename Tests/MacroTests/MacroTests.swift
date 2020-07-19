import XCTest
@testable import Macro

final class MacroTests: XCTestCase {
  
  func testDirname() throws {
    XCTAssertEqual(path.dirname("/usr/local/bin"), "/usr/local")    
  }
  func testBasename() throws {
    XCTAssertEqual(path.basename("/usr/local/bin"), "bin")
  }

  static var allTests = [
    ( "testDirname",  testDirname  ),
    ( "testBasename", testBasename ),
  ]
}
