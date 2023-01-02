//
//  Warnings.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2022 ZeeZide GmbH. All rights reserved.
//

import struct NIOConcurrencyHelpers.NIOLock

public extension process { // Warnings

  private static var _warningListeners = EventListenerSet<Warning>()
  private static let _warningListenersLock = NIOConcurrencyHelpers.NIOLock()
  
  static func onWarning(execute: @escaping ( Warning ) -> Void) {
    _warningListenersLock.lock()
    _warningListeners.add(execute)
    _warningListenersLock.unlock()
  }
  
  struct Warning {
    public let name    : String
    public let message : String
    public let error   : Swift.Error?
    // us have nope stack: TODO: there was something by IBM
    
    @usableFromInline
    init(name: String, message: String? = nil, error: Error? = nil) {
      self.name  = name
      self.error = error
      
      if      let s = message { self.message = s      }
      else if let e = error   { self.message = "\(e)" }
      else                    { self.message = "Unknown Error" }
    }
  }

  static func emit(warning w: Warning) {
    console.log("(Macro: \(pid)): \(w.name): \(w.message)")
    _warningListenersLock.lock()
    var warningListeners = _warningListeners
    _warningListenersLock.unlock()
    warningListeners.emit(w)
  }

  @inlinable
  static func emitWarning(_ warning: String, name: String = "Warning") {
    emit(warning: Warning(name: name, message: warning))
  }
  @inlinable
  static func emitWarning(_ warning: Error, name: String = "Warning") {
    emit(warning: Warning(name: name, error: warning))
  }
}
