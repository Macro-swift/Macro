//
//  BufferData.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)

import Foundation // Data, DataProtocol
import NIOCore
import NIOFoundationCompat

public extension Buffer {
  
  /**
   * Initialize the Buffer with the contents of the given `Data`. Copies the
   * bytes.
   *
   * - Parameters:
   *   - data: The bytes to copy into the buffer.
   */
  @inlinable
  init(_ data: Data) {
    self.init(capacity: data.count)
    byteBuffer.writeBytes(data)
  }
  
  @inlinable
  var data : Data {
    return byteBuffer.getData(at     : byteBuffer.readerIndex,
                              length : byteBuffer.readableBytes) ?? Data()
  }
}

extension Buffer: ContiguousBytes {
  
  @inlinable
  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R)
    rethrows -> R
  {
    return try byteBuffer.readableBytesView.withUnsafeBytes(body)
  }
  
}

extension Buffer: DataProtocol {
  
  @inlinable
  public var regions: CollectionOfOne<Buffer> { CollectionOfOne(self) }
}

#endif // canImport(Foundation)
