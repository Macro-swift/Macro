import XCTest
@testable import Macro
@testable import MacroTestUtilities

final class MacroBaseTests: XCTestCase {
  
  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }
  
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

    XCTAssertEqual(res.statusCode, 200)
    XCTAssertEqual(try res.writtenContent.toString(), "Hello World")
  }
  
  func testEncodableWrite() throws {
    struct Payload: Encodable { let answer: Int; let msg: String }
    let res = TestServerResponse()
    _ = res.write(Payload(answer: 42, msg: "hi"))
    res.end()
    let body = try res.writtenContent.toString()
    XCTAssertEqual(body, #"{"answer":42,"msg":"hi"}"#)
  }

  func testResponseCorking() throws {
    let res = http.ServerResponse(unsafeChannel: nil, log: MacroTestLogger)
    res.sendDate = false
    XCTAssertFalse(res.writableEnded)
    
    res.cork()
    
    res.writeHead(200, "OK")
    XCTAssertFalse(res.writableEnded)
    XCTAssertEqual(res.statusCode, 200)
    XCTAssertTrue(res.writableBuffer?.isEmpty ?? true)

    res.write("Hello World")
    XCTAssertFalse(res.writableEnded)
    XCTAssertEqual(try res.writableBuffer?.toString() ?? "", "Hello World")

    res.end()
    XCTAssertTrue(res.writableEnded)

    XCTAssertEqual(res.statusCode, 200)
    XCTAssertEqual(try res.writableBuffer?.toString() ?? "", "Hello World")
  }

  static let allTests = [
    ( "testDirname"         , testDirname         ),
    ( "testBasename"        , testBasename        ),
    ( "testTestResponse"    , testTestResponse    ),
    ( "testEncodableWrite"  , testEncodableWrite  ),
    ( "testResponseCorking" , testResponseCorking )
  ]
}
