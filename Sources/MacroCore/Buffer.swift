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
import struct NIO.ByteBufferAllocator

/**
 * A lightweight wrapper around the NIO ByteBuffer.
 *
 * Node Buffer API:
 * https://nodejs.org/api/buffer.html
 */
public struct Buffer {
  
  public var byteBuffer : ByteBuffer
  
  @inlinable public init(_ byteBuffer: ByteBuffer) {
    self.byteBuffer = byteBuffer
  }
  
  @inlinable public init(_ buffer: Buffer) {
    byteBuffer = buffer.byteBuffer
  }
  
  @inlinable
  public init(capacity  : Int = 1024,
              allocator : ByteBufferAllocator = MacroCore.shared.allocator)
  {
    byteBuffer = allocator.buffer(capacity: capacity)
  }
}

public extension Buffer {
  
  @inlinable init(_ data: Data) {
    self.init(capacity: data.count)
    byteBuffer.writeBytes(data)
  }
  @inlinable init(_ string: String) {
    guard let data = string.data(using: .utf8) else {
      fatalError("failed to encode string in UTF-8")
    }
    self.init(data)
  }
  
  @inlinable public var data : Data {
    return byteBuffer.getData(at     : byteBuffer.readerIndex,
                              length : byteBuffer.readableBytes) ?? Data()
  }
}

public extension Buffer {
  
  @inlinable
  static func from(_ string: String, encoding: String.Encoding = .utf8)
                throws -> Buffer
  {
    guard let data = string.data(using: encoding) else {
      throw CharsetConversionError.failedToConverData(encoding: encoding)
    }
    return Buffer(data)
  }
  
  @inlinable
  static func from(_ string: String, encoding: String) throws -> Buffer {
    switch encoding {
      case "hex":
        var buffer = Buffer(capacity: string.utf16.count / 2)
        guard buffer.writeHexString(string) else {
          throw DataDecodingError.failedToDecodeHexString
        }
        return buffer
      
      case "base64":
        guard let data = Data(base64Encoded: string) else {
          throw DataDecodingError.failedToDecodeBase64
        }
        return Buffer(data)

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
    guard let string = String(data: data, encoding: encoding) else {
      throw CharsetConversionError.failedToConvertString(encoding: encoding)
    }
    return string
  }
  
  @inlinable
  func toString(_ encoding: String) throws -> String {
    switch encoding {
      case "hex"    : return hexEncodedString()
      case "base64" : return data.base64EncodedString()
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

extension Buffer {

  public func hexEncodedString() -> String {
      // https://stackoverflow.com/questions/39075043/how-to-convert-data-to-hex
    return String(byteBuffer.readableBytesView.reduce(into: "".unicodeScalars, {
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
        byteBuffer.writeInteger(byte)
      }
      even = !even
    }
    return even
  }
}
