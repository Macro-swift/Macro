import XCTest
@testable import MacroCore
import struct NIO.ByteBuffer

final class CollectionTests: XCTestCase {

  func testByteBufferSearch() {
    var bb = ByteBuffer()
    bb.writeBytes([ 10, 20, 30, 30, 40, 50, 60 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 40 ])
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 3)
  }

  func testByteBufferSearchNoMatch() {
    var bb = ByteBuffer()
    bb.writeBytes([ 10, 20, 30, 30, 40, 50, 60 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 50 ])
    XCTAssertNil(idxMaybe)
  }

  func testByteBufferSearchEmpty() {
    let bb = ByteBuffer()
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 50 ])
    XCTAssertNil(idxMaybe)
  }

  func testByteBufferSearchMatchEmpty() {
    var bb = ByteBuffer()
    bb.writeBytes([ 10, 20, 30, 30, 40, 50, 60 ])
    let idxMaybe = bb.readableBytesView.firstIndex(of: [])
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 0)
  }
  
  func testByteBufferSearchLongerMatch() {
    var bb = ByteBuffer()
    bb.writeBytes([ 30, 50 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 10, 20, 30, 30, 40 ])
    XCTAssertNil(idxMaybe)
  }

  func testByteBufferSearchStableIndices() {
    var bb = ByteBuffer()
    bb.writeBytes([ 10, 20, 30, 30, 40, 50, 60 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 40 ])
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 3)

    _ = bb.readBytes(length: 3)
    let idxMaybe2 = bb.readableBytesView.firstIndex(of: [ 30, 40 ])
    XCTAssertNotNil(idxMaybe2)
    guard let idx2 = idxMaybe2 else { return }
    XCTAssertEqual(idx2, 3)
  }

  func testByteBufferSearchLeftEdge() {
    var bb = ByteBuffer()
    bb.writeBytes([ 30, 40, 50, 60, 10, 20, 30 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 40 ])
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 0)
  }

  func testByteBufferSearchRightEdge() {
    var bb = ByteBuffer()
    bb.writeBytes([ 10, 20, 30, 50, 60, 30, 40 ])
    
    let idxMaybe = bb.readableBytesView.firstIndex(of: [ 30, 40 ])
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 5)
  }

  func testByteBufferRemainingMatch() {
    do {
      var bb = ByteBuffer()
      bb.writeBytes([ 10, 20, 30, 50, 60, 30, 40 ])
      
      let idxMaybe = bb.readableBytesView
            .firstIndex(of: [ 30, 40, 50, 50 ], options: .partialSuffixMatch)
      XCTAssertNotNil(idxMaybe)
      guard let idx = idxMaybe else { return }
      XCTAssertEqual(idx, 5)
    }
    do {
      var bb = ByteBuffer()
      bb.writeBytes([ 30, 40, 50, 40, 60, 30, 40 ])
      
      let idxMaybe = bb.readableBytesView
            .firstIndex(of: [ 30, 40, 50, 50 ], options: .partialSuffixMatch)
      XCTAssertNotNil(idxMaybe)
      guard let idx = idxMaybe else { return }
      XCTAssertEqual(idx, 5)
    }
  }

  func testByteBufferSingleItemRemainingMatch() {
    var bb = ByteBuffer()
    bb.writeBytes([ 45 ])
    
    let idxMaybe = bb.readableBytesView
          .firstIndex(of: [ 45, 45, 50, 50 ], options: .partialSuffixMatch)
    XCTAssertNotNil(idxMaybe)
    guard let idx = idxMaybe else { return }
    XCTAssertEqual(idx, 0)
  }

  static var allTests = [
    ( "testByteBufferSearch"              , testByteBufferSearch              ),
    ( "testByteBufferSearchNoMatch"       , testByteBufferSearchNoMatch       ),
    ( "testByteBufferSearchEmpty"         , testByteBufferSearchEmpty         ),
    ( "testByteBufferSearchMatchEmpty"    , testByteBufferSearchMatchEmpty    ),
    ( "testByteBufferSearchLongerMatch"   , testByteBufferSearchLongerMatch   ),
    ( "testByteBufferSearchStableIndices" , testByteBufferSearchStableIndices ),
    ( "testByteBufferSearchLeftEdge"      , testByteBufferSearchLeftEdge      ),
    ( "testByteBufferSearchRightEdge"     , testByteBufferSearchRightEdge     ),
    ( "testByteBufferRemainingMatch"      , testByteBufferRemainingMatch      ),
    ( "testByteBufferSingleItemRemainingMatch",
      testByteBufferSingleItemRemainingMatch )
  ]
}
