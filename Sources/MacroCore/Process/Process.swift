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

public extension process {
  static let nextTick = MacroCore.nextTick
}

public extension process { // File System

  @inlinable
  static func chdir(path: String) throws {
    let rc = xsys.chdir(path)
    guard rc == 0 else { throw POSIXErrorCode(rawValue: xsys.errno)! }
  }

  @inlinable
  static func cwd() -> String {
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
  static var pid     : Int { return Int(getpid()) }

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
    switch signal.uppercased() {
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
}
