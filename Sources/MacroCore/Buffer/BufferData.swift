//
//  BufferData.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)

import struct Foundation.Data
import NIOCore
import NIOFoundationCompat

public extension Buffer {
  
  /**
   * Initialize the Buffer with the contents of the given `Data`. Copies the
   * bytes.
   */
  @inlinable init(_ data: Data) {
    self.init(capacity: data.count)
    byteBuffer.writeBytes(data)
  }
  
  @inlinable var data : Data {
    return byteBuffer.getData(at     : byteBuffer.readerIndex,
                              length : byteBuffer.readableBytes) ?? Data()
  }
}

#endif // canImport(Foundation)
