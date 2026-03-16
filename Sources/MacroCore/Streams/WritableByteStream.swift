//
//  WritableByteStream.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2026 ZeeZide GmbH. All rights reserved.
//

/**
 * A `Buffer` based stream.
 *
 * Note: `WritableStreamType` and `WritableByteStreamType` are not implemented
 *       here. It is just a base class.
 *
 * Hierarchy:
 * 
 * - ``WritableStreamBase``
 *   - ``WritableByteStream``
 */
open class WritableByteStream: WritableStreamBase<Buffer> {

  public typealias WritablePayload = Buffer
  
  open func _clearListeners() {
    finishListeners.removeAll()
    drainListeners .removeAll()
  }
}
