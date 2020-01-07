//
//  Buffer.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import Foundation
import NIOFoundationCompat
import struct NIO.ByteBuffer

/**
 * Node Buffer API:
 * https://nodejs.org/api/buffer.html
 * We use the NIO.ByteBuffer instead.
 *
 * The API is a bit different, a Node buffer is more like a prefilled array
 * of some size.
 */
public extension ByteBuffer {
  // Yes, I know. Do not extend types you don't own. etc etc.
  
  @inlinable
  static func from(_ string: String, encoding: String.Encoding = .utf8)
                throws -> ByteBuffer
  {
    guard let data = string.data(using: encoding) else {
      throw CharsetConversionError.failedToConverData(encoding: encoding)
    }
    var bb = MacroCore.shared.allocator.buffer(capacity: data.count)
    bb.writeBytes(data)
    return bb
  }
  
  @inlinable
  static func from(_ string: String, encoding: String) throws -> ByteBuffer {
    switch encoding {
      case "hex":
        var bb = MacroCore.shared.allocator
                  .buffer(capacity: string.utf16.count / 2)
        guard bb.writeHexString(string) else {
          throw DataDecodingError.failedToDecodeHexString
        }
        return bb
      
      case "base64":
        guard let data = Data(base64Encoded: string) else {
          throw DataDecodingError.failedToDecodeBase64
        }
        var bb = MacroCore.shared.allocator.buffer(capacity: data.count)
        bb.writeBytes(data)
        return bb

      default:
        return try from(string, encoding: .encodingWithName(encoding))
    }
  }

  @inlinable
  static func isEncoding(_ encoding: String) -> Bool {
    switch encoding {
      case "hex", "base64": return true
      default: return String.Encoding.isEncoding(encoding)
    }
  }
  
  @inlinable
  func toString(_ encoding: String.Encoding = .utf8) throws -> String {
    guard let data = getData(at: readerIndex, length: readableBytes) else {
      throw DataEncodingError.failedToReadData
    }
    guard let string = String(data: data, encoding: encoding) else {
      throw CharsetConversionError.failedToConvertString(encoding: encoding)
    }
    return string
  }
  
  @inlinable
  func toString(_ encoding: String) throws -> String {
    switch encoding {
      case "hex":
        return hexEncodedString()
      case "base64":
        guard let data = getData(at: readerIndex, length: readableBytes) else {
          throw DataEncodingError.failedToReadData
        }
        return data.base64EncodedString()
      default: return try toString(.encodingWithName(encoding))
    }
  }
}

public enum DataDecodingError: Swift.Error {
  case failedToDecodeHexString
  case failedToDecodeBase64
}
public enum DataEncodingError: Swift.Error {
  case failedToReadData
}

@usableFromInline
internal let hexAlphabet = "0123456789abcdef".unicodeScalars.map { $0 }

extension ByteBuffer {

  public func hexEncodedString() -> String {
      // https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex
    return String(readableBytesView.reduce(into: "".unicodeScalars, {
      ( result, value ) in
      result.append(hexAlphabet[Int(value / 16)])
      result.append(hexAlphabet[Int(value % 16)])
    }))
  }

  @inlinable
  mutating func writeHexString(_ hexString: String) -> Bool {
    // https://stackoverflow.com/questions/41485494/convert-hex-encoded-string
    func decodeNibble(u: UInt16) -> UInt8? {
      switch(u) {
        case 0x30 ... 0x39: return UInt8(u - 0x30)
        case 0x41 ... 0x46: return UInt8(u - 0x41 + 10)
        case 0x61 ... 0x66: return UInt8(u - 0x61 + 10)
        default:            return nil
      }
    }

    var even = true
    var byte : UInt8 = 0
    for c in hexString.utf16 {
      guard let val = decodeNibble(u: c) else { return false }
      if even {
        byte = val << 4
      }
      else {
        byte += val
        writeInteger(byte)
      }
      even = !even
    }
    return even
  }
}
