import XCTest
@testable import MacroCore
@testable import fs

final class PathTests: XCTestCase {
  
  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }
  
  func testBasename() {
    XCTAssertEqual(path.basename("hello"), "hello")
    XCTAssertEqual(path.basename("dir/hello"), "hello")
    XCTAssertEqual(path.basename("/dir/hello"), "hello")
    XCTAssertEqual(path.basename("/dir/hello.gif"), "hello.gif")
  }
  
  func testBasenameWithDrop() {
    XCTAssertEqual(path.basename("hello",          ".gif"), "hello")
    XCTAssertEqual(path.basename("dir/hello",      ".gif"), "hello")
    XCTAssertEqual(path.basename("/dir/hello",     ".gif"), "hello")
    XCTAssertEqual(path.basename("/dir/hello.gif", ".gif"), "hello")
  }

  func testDirname() {
    XCTAssertEqual(path.dirname("hello"), "hello")
    XCTAssertEqual(path.dirname("dir/hello"), "dir")
    XCTAssertEqual(path.dirname("/dir/hello"), "/dir")
    XCTAssertEqual(path.dirname("/dir/sub/hello"), "/dir/sub")
  }

  func testExtname() {
    XCTAssertEqual(path.extname("home")        , "")
    XCTAssertEqual(path.extname("folder/home") , "")
    XCTAssertEqual(path.extname(".gitignore")  , "")  // leading dot, not an ext
    XCTAssertEqual(path.extname("archive.")    , ".") // trailing dot, extension
    XCTAssertEqual(path.extname("image.gif")   , ".gif")
  }

  static var allTests = [
    ( "testBasename"         , testBasename         ),
    ( "testBasenameWithDrop" , testBasenameWithDrop ),
    ( "testDirname"          , testDirname          ),
    ( "testExtname"          , testExtname          )
  ]
}
