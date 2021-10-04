//
//  Process.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2021 ZeeZide GmbH. All rights reserved.
//

import class Foundation.ProcessInfo
import xsys

#if os(Windows)
  import WinSDK
#elseif os(Linux)
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
    let pathMaybe = xsys.getcwd(nil /* malloc */, 0)
    assert(pathMaybe != nil, "process has no cwd??")
    guard let path = pathMaybe else { return "" }
    defer { free(path) }

    let s = String(validatingUTF8: path)
    assert(s != nil, "could not convert cwd to String?!")
    return s ?? "/tmp"
  }
}

public extension process { // Process Info

  #if os(Windows)
    static let platform = "win32"
  #elseif os(Linux)
    static let platform = "linux"
  #else
    static let platform = "darwin"
  #endif
}

#if !os(Windows)
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

  // TODO: arch
  // TODO: release
}
#endif // !os(Windows)

public extension process { // Run Control

  /**
   * The exit code to use if `exit` is called without an explicit code,
   * defaults to `0` (aka no error).
   *
   * This can be used to change the default to some error code, so all exits
   * will error out, unless a success code is used. For example:
   *
   *     process.exitCode = 1
   *
   *     guard process.argv.count > 1 else { process.exit() } // will fail
   *     if answer == 42                   { process.exit() } // will fail
   *
   *     print("OK, all good.")
   *     process.exit(0) // explict successful exit
   *
   */
  static var exitCode : Int {
    set { MacroCore.shared.exitCode = newValue }
    get { return MacroCore.shared.exitCode }
  }
  
  /**
   * Terminate the process with the given process exit code.
   *
   * It no code is passed in, the current value of the `process.exitCode`
   * property is used (which itself defaults to 0).
   *
   * - Parameters:
   *   - code: The optional exit code, defaults to `process.exitCode`.
   */
  @inlinable
  static func exit(_ code: Int? = nil) -> Never { MacroCore.shared.exit(code) }

  /**
   * Terminate the process with the given exit code associated with the
   * given value.
   *
   * This can be used with enums like so:
   *
   *     enum ExitCodes: Int {
   *       case directoryMissing = 1
   *       case outOfMemory      = 2
   *     }
   * 
   * - Parameters:
   *   - code: The optional exit code, defaults to `process.exitCode`.
   */
  @inlinable
  static func exit<C>(_ code: C) -> Never
                where C: RawRepresentable, C.RawValue == Int
  {
    exit(code.rawValue)
  }

  @inlinable
  @available(*, deprecated, message: "Avoid argument label, just `exit(10)`.")
  static func exit(code: Int?) { exit(code) }
}

#if !os(Windows)
public extension process { // Run Control

  static let abort = xsys.abort

  @inlinable
  static func kill(_ pid: Int, _ signal: Int32 = xsys.SIGTERM) throws {
    let rc = xsys.kill(pid_t(pid), signal)
    guard rc == 0 else { throw POSIXErrorCode(rawValue: xsys.errno)! }
  }
  @inlinable
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
#endif // !os(Windows)
