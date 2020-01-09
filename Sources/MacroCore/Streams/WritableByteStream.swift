//
//  WritableByteStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * A `Buffer` based stream.
 *
 * Note: `WritableStreamType` and `WritableByteStreamType` are not implemented
 *       here. It is just a base class.
 */
open class WritableByteStream: WritableStreamBase<Buffer> {

  public typealias WritablePayload = Buffer
  
  open func _clearListeners() {
    finishListeners.removeAll()
    drainListeners .removeAll()
  }
}
