import XCTest
@testable import MacroCore
import NIO

final class ByteBufferTests: XCTestCase {

  func testByteBufferAssumptions() {
    var bb = ByteBuffer()
    XCTAssertEqual(bb.readerIndex   , 0)
    XCTAssertEqual(bb.readableBytes , 0)
    XCTAssertEqual(bb.writerIndex   , 0)

    bb.writeBytes([ 10, 20, 30, 40, 50, 60 ])
    XCTAssertEqual(bb.readerIndex   , 0)
    XCTAssertEqual(bb.readableBytes , 6)
    XCTAssertEqual(bb.writerIndex   , 6)
    
    XCTAssertEqual(bb.readableBytesView.count      , 6)
    XCTAssertEqual(bb.readableBytesView.startIndex , 0)
    
    let b0 = bb.readBytes(length: 1) ?? []
    XCTAssertEqual(b0.count         , 1)
    XCTAssertEqual(b0.first         , 10)
    XCTAssertEqual(bb.readerIndex   , 1)
    XCTAssertEqual(bb.readableBytes , 5)
    XCTAssertEqual(bb.writerIndex   , 6)
    
    XCTAssertEqual(bb.readableBytesView.count      , 5)
    XCTAssertEqual(bb.readableBytesView.startIndex , 1)
  }

  static var allTests = [
    ( "testByteBufferAssumptions" , testByteBufferAssumptions )
  ]
}
