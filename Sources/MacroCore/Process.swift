//
//  Process.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//


import class Foundation.ProcessInfo
import xsys

#if os(Linux)
  import Glibc
#else
  import Darwin
  // importing this from xsys doesn't seem to work
  import Foundation // this is for POSIXError : Error
#endif


public enum process {}

public extension process { // Environment
  
  @inlinable
  static var argv : [ String ] { return CommandLine.arguments }
  
  @inlinable
  static var env  : [ String : String ] {
    return ProcessInfo.processInfo.environment
  }
}

public extension process { // File System

  func chdir(path: String) throws {
    let rc = xsys.chdir(path)
    guard rc == 0 else { throw POSIXErrorCode(rawValue: xsys.errno)! }
  }

  func cwd() -> String {
    let rc = xsys.getcwd(nil /* malloc */, 0)
    assert(rc != nil, "process has no cwd??")
    defer { free(rc) }
    guard rc != nil else { return "" }
    
    let s = String(validatingUTF8: rc!)
    assert(s != nil, "could not convert cwd to String?!")
    return s!
  }
}

public extension process { // Process Info
  
  @inlinable
  static var pid : Int { return Int(getpid()) }

  static let getegid = xsys.getegid
  static let geteuid = xsys.geteuid
  static let getgid  = xsys.getgid
  static let getuid  = xsys.getuid
  // TODO: getgroups, initgroups, setegid, seteuid, setgid, setgroups, setuid

  // TODO: hrtime()
  // TODO: memoryUsage()
  // TODO: title { set get }
  // TODO: uptime

  #if os(Linux)
    static let platform = "linux"
  #else
    static let platform = "darwin"
  #endif
  
  // TODO: arch
  // TODO: release

  #if os(Linux)
    public let isRunningInXCode = false
  #else
    static let isRunningInXCode : Bool = {
      // TBD: is there a better way?
      guard let s = xsys.getenv("XPC_SERVICE_NAME") else { return false }
      return strstr(s, "Xcode") != nil
    }()
  #endif
}

public extension process { // Run Control

  static let abort = xsys.abort

  static var exitCode : Int {
    set { MacroCore.shared.exitCode = newValue }
    get { return MacroCore.shared.exitCode }
  }
  static func exit(code: Int? = nil) { MacroCore.shared.exit(code) }


  static func kill(_ pid: Int, _ signal: Int32 = xsys.SIGTERM) throws {
    let rc = xsys.kill(pid_t(pid), signal)
    guard rc == 0 else { throw POSIXErrorCode(rawValue: xsys.errno)! }
  }
  static func kill(_ pid: Int, _ signal: String) throws {
    var sc : Int32 = xsys.SIGTERM
    switch signal {
      case "SIGTERM": sc = xsys.SIGTERM
      case "SIGHUP":  sc = xsys.SIGHUP
      case "SIGINT":  sc = xsys.SIGINT
      case "SIGQUIT": sc = xsys.SIGQUIT
      case "SIGKILL": sc = xsys.SIGKILL
      case "SIGSTOP": sc = xsys.SIGSTOP
      default: emitWarning("unsupported signal: \(signal)")
    }
    try kill(pid, sc)
  }

  static let nextTick = MacroCore.nextTick

}

import class NIOConcurrencyHelpers.Lock

public extension process { // Warnings

  private static var _warningListeners = EventListenerSet<Warning>()
  private static let _warningListenersLock = NIOConcurrencyHelpers.Lock()
  
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


// MARK: - Helpers

public extension process {
  
  @inlinable
  static func getenv(_ environmentVarName : String,
                     defaultValue         : Int,
                     lowerWarningBound    : Int? = nil,
                     upperWarningBound    : Int? = nil) -> Int
  {
    if let s = process.env[environmentVarName], !s.isEmpty {
      guard let value = Int(s), value > 0 else {
        console.error("invalid int value in env \(environmentVarName):", s)
        return defaultValue
      }
      if let wv = lowerWarningBound, value < wv {
        console.warn("pretty small \(environmentVarName) value:", value)
      }
      if let wv = upperWarningBound, value > wv {
        console.warn("pretty large \(environmentVarName) value:", value)
      }
      return value
    }
    else {
      return defaultValue
    }
  }
}
