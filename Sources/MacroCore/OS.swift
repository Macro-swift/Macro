//
//  OS.swift
//  Macro
//
//  Created by Helge Heß.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
import WinSDK
#elseif os(Linux) || os(Android)
import Glibc
#elseif os(WASI)
import WASILibc
#else
import Darwin
#endif

public enum OSModule: Sendable {}


// MARK: - Paths

public extension OSModule {

  /**
   * Returns the operating system's default directory for temporary files.
   *
   * Honours the `TMPDIR`, `TMP`, and `TEMP` environment variables (in that
   * order). Falls back to `/tmp` on POSIX systems and `C:\Windows\Temp` on
   * Windows. A trailing path separator is stripped from non-root paths.
   */
  @inlinable
  static func tmpdir() -> String {
    for key in [ "TMPDIR", "TMP", "TEMP" ] {
      guard let v = process.env[key], !v.isEmpty else { continue }
      return trimTrailingSeparator(v)
    }
    #if os(Windows)
    return #"C:\Windows\Temp"#
    #else
    return "/tmp"
    #endif
  }

  /**
   * Returns the home directory of the current user.
   *
   * On POSIX, reads `$HOME`, falling back to the `pw_dir` of the calling
   * user. On Windows, reads `%USERPROFILE%`.
   * 
   * May do I/O if HOME is not set on Unix (call to getpwuid).
   */
  @inlinable
  static func homedir() -> String {
    #if os(Windows)
    if let h = process.env["USERPROFILE"], !h.isEmpty { return h }
    if let h = process.env["HOME"],        !h.isEmpty { return h }
    return #"C:\"#
    #else
    if let h = process.env["HOME"], !h.isEmpty { return h }
    let pw = getpwuid(getuid())
    if let pw = pw, let dir = pw.pointee.pw_dir {
      return String(cString: dir)
    }
    return "/"
    #endif
  }

  #if os(Windows)
  /// File-name of the platform's null device.
  static let devNull = #"\\.\nul"#
  #else
  /// File-name of the platform's null device.
  static let devNull = "/dev/null"
  #endif

  #if os(Windows)
  /// Platform-native line separator (`"\n"` on POSIX, `"\r\n"` on Windows).
  static let EOL = "\r\n" // careful, may become a single Unicode char!
  #else
  /// Platform-native line separator (`"\n"` on POSIX, `"\r\n"` on Windows).
  static let EOL = "\r"
  #endif

  @usableFromInline
  internal static func trimTrailingSeparator(_ s: String) -> String {
    guard let last = s.last else { return "" }
    #if os(Windows)
    return last == "/" || last == "\\" ? s : String(s.dropLast())
    #else
    return last == "/" ? s : String(s.dropLast())
    #endif
  }

  /**
   * Returns the host name of the machine. On error returns an empty string.
   */
  @inlinable
  static func hostname() -> String {
    var buf = [ CChar ]( repeating: 0, count: 256 )
    let rc  = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
      return gethostname(ptr.baseAddress, ptr.count)
    }
    guard rc == 0 else { return "" }
    return String(cString: buf)
  }

  /**
   * Returns the operating system platform identifier.
   * 
   * `"darwin"`, `"linux"`, `"win32"`, ...
   */
  @inlinable
  static func platform() -> String {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    return "darwin"
    #elseif os(Linux)
    return "linux"
    #elseif os(Windows)
    return "win32"
    #elseif os(FreeBSD)
    return "freebsd"
    #elseif os(OpenBSD)
    return "openbsd"
    #elseif os(Android)
    return "android"
    #elseif os(WASI)
    return "wasi"
    #else
    return "unknown"
    #endif
  }

  /**
   * Returns the operating system name as reported by `uname -s`.
   * 
   * E.g. `"Darwin"`, `"Linux"`, `"Windows_NT"`.
   */
  @inlinable
  static func type() -> String {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    return "Darwin"
    #elseif os(Linux) || os(Android)
    return "Linux"
    #elseif os(Windows)
    return "Windows_NT"
    #elseif os(FreeBSD)
    return "FreeBSD"
    #elseif os(OpenBSD)
    return "OpenBSD"
    #elseif os(WASI)
    return "WASI"
    #else
    return "Unknown"
    #endif
  }

  /**
   * Returns the CPU architecture.
   * 
   * `"arm64"`, `"x64"`, `"ia32"`, `"arm"`, ...
   */
  @inlinable
  static func arch() -> String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x64"
    #elseif arch(i386)
    return "ia32"
    #elseif arch(arm)
    return "arm"
    #elseif arch(powerpc64) || arch(powerpc64le)
    return "ppc64"
    #elseif arch(s390x)
    return "s390x"
    #elseif arch(wasm32)
    return "wasm32"
    #else
    return "unknown"
    #endif
  }

  /// CPU endianness: `"BE"` or `"LE"`.
  @inlinable
  static func endianness() -> String {
    return 1.littleEndian == 1 ? "LE" : "BE"
  }
}
