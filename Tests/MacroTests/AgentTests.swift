import XCTest
@testable import http
@testable import Macro
@testable import MacroTestUtilities

final class AgentTests: XCTestCase {
  
  func testSimpleGet() throws {
    
    let exp = expectation(description: "get result")
    
    http.get("https://zeezide.de") { res in
      XCTAssertEqual(res.status, .ok)
      
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
    
    waitForExpectations(timeout: 5, handler: nil)
  }

  static var allTests = [
    ( "testSimpleGet" , testSimpleGet ),
  ]
}
