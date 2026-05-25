//
//  time.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 19/05/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(WASI)
  import WASILibc
  // TBD: WASI support is untested.

  public typealias struct_tm = WASILibc.tm
  public typealias time_t    = WASILibc.time_t

  public let time          = WASILibc.time
  public let gmtime_r      = WASILibc.gmtime_r
  public let localtime_r   = WASILibc.localtime_r
  public let strftime      = WASILibc.strftime

#elseif os(Linux) || os(Android)
  import Glibc

  public typealias struct_tm = Glibc.tm
  public typealias time_t    = Glibc.time_t
  
  public let time          = Glibc.time
  public let gmtime_r      = Glibc.gmtime_r
  public let localtime_r   = Glibc.localtime_r
  public let strftime      = Glibc.strftime
  
#else
  import Darwin
  
  public typealias struct_tm = Darwin.tm
  public typealias time_t    = Darwin.time_t

  public let time          = Darwin.time
  public let gmtime_r      = Darwin.gmtime_r
  public let localtime_r   = Darwin.localtime_r
  public let strftime      = Darwin.strftime
#endif

#if !os(Windows)

// MARK: - Time Helpers

/// Unix timestamp. `time_t` has the Y2038 issue and its granularity is limited
/// to seconds.
/// Unix timestamps are counted in seconds starting Jan 1st 1970 00:00:00, UTC.
public extension time_t {
  
  /// Returns the current time.
  @inlinable
  static var now : time_t { return xsys.time(nil) }
  
  /// Initialize the `time_t` value from Unix `tm` value (date components).
  /// Assumes the values are given in *local time*.
  /// Remember that the `time_t` itself is in UTC.
  @inlinable
  init(_ tm: xsys.struct_tm) {
    self = tm.localTime
  }
  /// Initialize the `time_t` value from Unix `tm` value (date components).
  /// Assumes the values are given in *UTC time*.
  /// Remember that the `time_t` itself is in UTC.
  @inlinable
  init(utc tm: xsys.struct_tm) {
    self = tm.utcTime
  }
  
  /// Converts the `time_t` timestamp into date components (`tz` struct) living
  /// in the UTC timezone.
  /// Remember that the `time_t` itself is in UTC.
  @inlinable
  var componentsInUTC : xsys.struct_tm {
    var t  = self
    var tm = xsys.struct_tm()
    _ = xsys.gmtime_r(&t, &tm)
    return tm
  }
  
  /// Converts the `time_t` timestamp into date components (`tz` struct) living
  /// in the local timezone of the Unix environment.
  /// Remember that the `time_t` itself is in UTC.
  @inlinable
  var componentsInLocalTime : xsys.struct_tm {
    var t  = self
    var tm = xsys.struct_tm()
    _ = xsys.localtime_r(&t, &tm)
    return tm
  }
  
  /** Example `strftime` format:
   *   "%a, %d %b %Y %H:%M:%S GMT"
   *
   * This function converts the timestamp into UTC time components to format
   * the value.
   *
   * Example call:
   * ```swift
   * xsys.time(nil).format("%a, %d %b %Y %H:%M:%S %Z")
   * ```
  */
  @inlinable
  func format(_ sf: String) -> String {
    return self.componentsInUTC.format(sf)
  }

  /**
   * Optimized version that produces HTTP date strings (RFC 1123).
   *
   * E.g. "Sun, 17 May 2026 12:34:56 GMT". Always 29 ASCII chars long.
   */
  @inlinable
  var httpDateString : String {
    let tm = self.componentsInUTC
    let bytes = [ UInt8 ](unsafeUninitializedCapacity: 29) {
      buf, count in
      let day  = rfc1123DayBytes  [Int(tm.tm_wday) % 7]
      let monB = rfc1123MonthBytes[Int(tm.tm_mon)  % 12]
      buf[0]  = day.0;  buf[1]  = day.1;  buf[2]  = day.2
      buf[3]  = UInt8(ascii: ",")
      buf[4]  = UInt8(ascii: " ")
      writeTwoDigit(Int(tm.tm_mday), into: buf, at: 5)
      buf[7]  = UInt8(ascii: " ")
      buf[8]  = monB.0; buf[9]  = monB.1; buf[10] = monB.2
      buf[11] = UInt8(ascii: " ")
      writeFourDigit(Int(tm.tm_year) + 1900, into: buf, at: 12)
      buf[16] = UInt8(ascii: " ")
      writeTwoDigit(Int(tm.tm_hour), into: buf, at: 17)
      buf[19] = UInt8(ascii: ":")
      writeTwoDigit(Int(tm.tm_min),  into: buf, at: 20)
      buf[22] = UInt8(ascii: ":")
      writeTwoDigit(Int(tm.tm_sec),  into: buf, at: 23)
      buf[25] = UInt8(ascii: " ")
      buf[26] = UInt8(ascii: "G")
      buf[27] = UInt8(ascii: "M")
      buf[28] = UInt8(ascii: "T")
      count = 29
    }
    return String(decoding: bytes, as: UTF8.self)
  }

  /**
   * Optimized version that produces ISO UTC date strings.
   *
   * E.g. "2026-05-17T12:34:56Z". Always 20 ASCII chars long.
   */
  @inlinable
  var iso8601String : String {
    let tm = self.componentsInUTC
    let bytes = [ UInt8 ](unsafeUninitializedCapacity: 20) {
      buf, count in
      writeFourDigit(Int(tm.tm_year) + 1900, into: buf, at:  0)
      buf[4]  = UInt8(ascii: "-")
      writeTwoDigit (Int(tm.tm_mon)  + 1,    into: buf, at:  5)
      buf[7]  = UInt8(ascii: "-")
      writeTwoDigit (Int(tm.tm_mday),        into: buf, at:  8)
      buf[10] = UInt8(ascii: "T")
      writeTwoDigit (Int(tm.tm_hour),        into: buf, at: 11)
      buf[13] = UInt8(ascii: ":")
      writeTwoDigit (Int(tm.tm_min),         into: buf, at: 14)
      buf[16] = UInt8(ascii: ":")
      writeTwoDigit (Int(tm.tm_sec),         into: buf, at: 17)
      buf[19] = UInt8(ascii: "Z")
      count = 20
    }
    return String(decoding: bytes, as: UTF8.self)
  }
}

// MARK: - Fast Date Formatter Helpers

@usableFromInline
internal let rfc1123DayBytes: [ (UInt8, UInt8, UInt8) ] = [
  (0x53, 0x75, 0x6E), // Sun
  (0x4D, 0x6F, 0x6E), // Mon
  (0x54, 0x75, 0x65), // Tue
  (0x57, 0x65, 0x64), // Wed
  (0x54, 0x68, 0x75), // Thu
  (0x46, 0x72, 0x69), // Fri
  (0x53, 0x61, 0x74)  // Sat
]

@usableFromInline
internal let rfc1123MonthBytes: [ (UInt8, UInt8, UInt8) ] = [
  (0x4A, 0x61, 0x6E), // Jan
  (0x46, 0x65, 0x62), // Feb
  (0x4D, 0x61, 0x72), // Mar
  (0x41, 0x70, 0x72), // Apr
  (0x4D, 0x61, 0x79), // May
  (0x4A, 0x75, 0x6E), // Jun
  (0x4A, 0x75, 0x6C), // Jul
  (0x41, 0x75, 0x67), // Aug
  (0x53, 0x65, 0x70), // Sep
  (0x4F, 0x63, 0x74), // Oct
  (0x4E, 0x6F, 0x76), // Nov
  (0x44, 0x65, 0x63)  // Dec
]

/// Two ASCII digits (`'00'..='99'`) of `n` written at `buf[offset]` and
/// `buf[offset+1]`. ASCII '0' is 0x30. `n` is clamped to `0...99`.
@inlinable
internal func writeTwoDigit(_ n: Int,
                            into buf: UnsafeMutableBufferPointer<UInt8>,
                            at offset: Int)
{
  let v = (n < 0 || n > 99) ? 0 : n
  buf[offset]     = UInt8(0x30 + v / 10)
  buf[offset + 1] = UInt8(0x30 + v % 10)
}

/// Four ASCII digits of `n` written at `buf[offset ..< offset+4]`.
/// `n` is clamped to `1000...9999` (falls back to 1900 if out of range).
@inlinable
internal func writeFourDigit(_ n: Int,
                             into buf: UnsafeMutableBufferPointer<UInt8>,
                             at offset: Int)
{
  let v = (n < 1000 || n > 9999) ? 1900 : n
  writeTwoDigit(v / 100, into: buf, at: offset)
  writeTwoDigit(v % 100, into: buf, at: offset + 2)
}

/// The Unix `tm` struct is essentially NSDateComponents PLUS some timezone
/// information (isDST, offset, tz abbrev name).
public extension xsys.struct_tm {
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the local timezone.
  @inlinable
  init(_ tm: time_t) {
    self = tm.componentsInLocalTime
  }
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the UTC timezone.
  @inlinable
  init(utc tm: time_t) {
    self = tm.componentsInUTC
  }

  @inlinable
  var utcTime : time_t {
    var tm = self
    return timegm(&tm)
  }
  @inlinable
  var localTime : time_t {
    var tm = self
    return mktime(&tm)
  }
  
  /// Example `strftime` format (`man strftime`):
  ///   "%a, %d %b %Y %H:%M:%S GMT"
  ///
  @inlinable
  func format(_ sf: String, defaultCapacity: Int = 100) -> String {
    var tm = self
    
    // Yes, yes, I know.
    let attempt1Capacity = defaultCapacity
    let attempt2Capacity = defaultCapacity > 1024 ? defaultCapacity * 2 : 1024
    var capacity = attempt1Capacity
    
    var buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
    defer { buf.deallocate() }
  
    let rc = xsys.strftime(buf, capacity, sf, &tm)
  
    if rc == 0 {
      buf.deallocate()
      capacity = attempt2Capacity
      buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
  
      let rc = xsys.strftime(buf, capacity, sf, &tm)
      assert(rc != 0)
      guard rc != 0 else { return "" }
    }
  
    return String(cString: buf);
  }
}

#endif // !os(Windows)
