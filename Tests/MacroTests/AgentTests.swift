import XCTest
@testable import http
@testable import Macro
@testable import MacroTestUtilities

final class AgentTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  func testSimpleGet() {
    let exp = expectation(description: "get result")
    
    http.get("https://zeezide.de") { res in
      XCTAssertEqual(res.status, .ok)
      
      res.onError { error in
        XCTAssert(false, "an error happened: \(error)")
      }
      
      res | concat { buffer in
        do {
          let s = try buffer.toString()
          XCTAssert(s.contains("<html"))
          XCTAssert(s.contains("ZeeZide"))
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
    let exp = expectation(description: "post result")
    
    let options = http.ClientRequestOptions(
      protocol : "https:",
      host     : "jsonplaceholder.typicode.com",
      method   : "POST",
      path     : "/posts"
    )
    
    let req = http.request(options) { res in
      XCTAssertEqual(res.status, .created)
      
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
