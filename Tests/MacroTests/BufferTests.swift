import XCTest
@testable import MacroCore

final class BufferTests: XCTestCase {

  func testIndexOf() throws {
    // matching https://nodejs.org/api/buffer.html#buffer_buf_indexof_value_byteoffset_encoding
    let buf = try Buffer.from("this is a buffer")
    
    XCTAssertEqual(0, buf.indexOf("this"))
    XCTAssertEqual(2, buf.indexOf("is"))
    XCTAssertEqual(8, buf.indexOf(try Buffer.from("a buffer")))
    XCTAssertEqual(8, buf.indexOf(97)) // ASCII 'a'

    XCTAssertEqual(-1, buf.indexOf(try Buffer.from("a buffer example")))
    XCTAssertEqual(8,  buf.indexOf(try Buffer.from("a buffer example")
                                        .slice(0, 8)))

    let utf16Buffer =
          try Buffer.from("\u{039a}\u{0391}\u{03a3}\u{03a3}\u{0395}", "utf16le")

    XCTAssertEqual(4, utf16Buffer.indexOf("\u{03a3}",  0, "utf16le"))
    XCTAssertEqual(6, utf16Buffer.indexOf("\u{03a3}", -4, "utf16le"))
 }
  
  func testLastIndexOf() throws {
    // We don't support many operations yet :-)
    let buf = try Buffer.from("this buffer is a buffer")
    XCTAssertEqual(15, buf.lastIndexOf(97)) // ASCII 'a'
  }
  
  func testSlice() throws {
    let buf = try Buffer.from("buffer")
    
    let slice = buf.slice(2, -2)
    XCTAssertEqual(slice.count, 2)
    XCTAssertEqual(slice[0], 102)
    XCTAssertEqual(slice[1], 102)
    
    let slicedSlice = slice.slice(1)
    XCTAssertEqual(slicedSlice.count, 1)
    XCTAssertEqual(slicedSlice[0], 102)
  }
  
  func testJSON() throws {
    let buf         = Buffer.from([ 0x1, 0x2, 0x3, 0x4, 0x5 ])
    let stringMaybe = json.stringify(buf)
    XCTAssertNotNil(stringMaybe)
    guard let string = stringMaybe else { return }

    XCTAssert(string.contains("Buffer"))
    XCTAssert(string.contains("data"))
    XCTAssert(string.contains("type"))
    
    let jsonObjMaybe = json.parse(string)
    XCTAssertNotNil(jsonObjMaybe, "Could not parse JSON \(string)")
    guard let jsonObj = jsonObjMaybe else { return }
    
    guard let dict     = jsonObj as? [ String : Any ],
          let jsonType = dict["type"] as? String,
          let jsonData = dict["data"] as? [ Int ]
    else {
      XCTAssert(false, "Unexpected JSON structure: \(jsonObj)")
      return
    }
    
    XCTAssertEqual(jsonType, "Buffer")
    XCTAssertEqual(jsonData, [ 0x1, 0x2, 0x3, 0x4, 0x5 ])
  }
  
  func testDescription() throws {
    do {
      let buf = Buffer.from([ 0x1, 0x2, 0x3, 0x4, 0x5 ])
      let s   = buf.description
      XCTAssertEqual(s, "<Buffer 01 02 03 04 05>")
    }
    
    do {
      let buf = Buffer.from([ UInt8 ](repeating: 0x42, count: 100))
      let s   = buf.description
      XCTAssert(s.hasPrefix("<Buffer: #100 42 42 42 "))
      XCTAssert(s.hasSuffix("…>"))
      XCTAssert(s.count < 200)
    }
  }

  static var allTests = [
    ( "testIndexOf"     , testIndexOf     ),
    ( "testLastIndexOf" , testLastIndexOf ),
    ( "testSlice"       , testSlice       ),
    ( "testJSON"        , testJSON        ),
    ( "testDescription" , testDescription )
  ]
}
