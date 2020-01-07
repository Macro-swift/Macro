//
//  WritableByteStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer

/**
 * A `ByteBuffer` based stream.
 *
 * Note: `WritableStreamType` and `WritableByteStreamType` are not implemented
 *       here. It is just a base class.
 */
open class WritableByteStream: WritableStreamBase<ByteBuffer> {

  public typealias WritablePayload = ByteBuffer
  
  open func _clearListeners() {
    finishListeners.removeAll()
    drainListeners .removeAll()
  }
}
