import XCTest
@testable import Macro
@testable import MacroTestUtilities

final class MacroTests: XCTestCase {
  
  func testDirname() throws {
    XCTAssertEqual(path.dirname("/usr/local/bin"), "/usr/local")    
  }
  func testBasename() throws {
    XCTAssertEqual(path.basename("/usr/local/bin"), "bin")
  }
  
  func testTestResponse() throws {
    let res = TestServerResponse()
    XCTAssertFalse(res.writableEnded)

    res.writeHead(200, "OK")
    XCTAssertFalse(res.writableEnded)
    XCTAssertEqual(res.statusCode, 200)
    XCTAssertTrue(res.writtenContent.isEmpty)

    res.write("Hello World")
    XCTAssertFalse(res.writableEnded)
    XCTAssertEqual(try res.writtenContent.toString(), "Hello World")

    res.end()
    XCTAssertTrue(res.writableEnded)

    XCTAssertTrue(res.writableEnded)
    XCTAssertEqual(res.statusCode, 200)
    XCTAssertEqual(try res.writtenContent.toString(), "Hello World")
  }

  static var allTests = [
    ( "testDirname",  testDirname  ),
    ( "testBasename", testBasename ),
  ]
}
