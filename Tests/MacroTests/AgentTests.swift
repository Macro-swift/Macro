import XCTest
@testable import http
@testable import Macro
@testable import MacroTestUtilities

final class AgentTests: XCTestCase {
  
  let runsInCI = env["CI"] == "true"

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  func testSimpleGet() {
    let exp = expectation(description: "get result")
    
    http.get("https://zeezide.de") { res in
      XCTAssertEqual(res.statusCode, 200, "Status code is not 200!")
      
      res.onError { error in
        XCTAssert(false, "an error happened: \(error)")
      }
      
      res | concat { buffer in
        do {
          let s = try buffer.toString()
          XCTAssert(s.contains("<html"),
                    "buffer does not start w/ <html: \(s)")
          XCTAssert(s.contains("ZeeZide"),
                    "buffer does not contain ZeeZide: \(s)")
        }
        catch {
          XCTAssert(false, "failed to grab string: \(error)")
        }
      }
      
      res.onEnd {
        exp.fulfill()
      }
    }
    
    waitForExpectations(timeout: 20, handler: nil)
  }

  func testSimplePost() throws {
    // Looks like typicode returns a 403 for GH Actions
    try XCTSkipIf(runsInCI, "Not running in CI")

    let exp = expectation(description: "post result")
    
    let options = http.ClientRequestOptions(
      protocol : "https:",
      host     : "jsonplaceholder.typicode.com",
      method   : "POST",
      path     : "/posts"
    )
    
    let req = http.request(options) { res in
      XCTAssertEqual(res.statusCode, 201)
      
      res.onError { error in
        XCTAssert(false, "an error happened: \(error)")
      }
      
      var content : String?
      res | concat { buffer in
        do { content = try buffer.toString() }
        catch { XCTAssert(false, "failed to grab string: \(error)") }
      }
      
      res.onEnd {
        XCTAssertNotNil(content)
        if let content = content {
          XCTAssert(content.contains("Blubs"))
        }
        
        exp.fulfill()
      }
    }
        
    let didWrite = req.write(
      """
      { "userId": 1,
        "title": "Blubs",
        "body": "Rummss" }
      """
    )
    XCTAssertTrue(didWrite)
    req.end()
    
    waitForExpectations(timeout: 20, handler: nil)
  }
  
  static var allTests = [
    ( "testSimpleGet"  , testSimpleGet  ),
    ( "testSimplePost" , testSimplePost )
  ]
}
