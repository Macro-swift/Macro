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
  init(_ tm: xsys.struct_tm) { self = tm.localTime }
  /// Initialize the `time_t` value from Unix `tm` value (date components).
  /// Assumes the values are given in *UTC time*.
  /// Remember that the `time_t` itself is in UTC.
  @inlinable
  init(utc tm: xsys.struct_tm) { self = tm.utcTime }
  
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
  func format(_ sf: String) -> String { return self.componentsInUTC.format(sf) }

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
      let day  = rfc1123DayBytes[Int(tm.tm_wday) % 7]
      let monB = rfc1123MonthBytes[Int(tm.tm_mon)  % 12]
      buf[0]  = day.0;  buf[1]  = day.1;  buf[2]  = day.2
      buf[3]  = UInt8(ascii: ","); buf[4]  = UInt8(ascii: " ")
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
      buf[25] = UInt8(ascii: " "); buf[26] = UInt8(ascii: "G")
      buf[27] = UInt8(ascii: "M"); buf[28] = UInt8(ascii: "T")
      count = 29
    }
    return String(decoding: bytes, as: UTF8.self)
  }

  /**
   * Produce ISO UTC date strings (e.g. `2026-05-17T12:34:56Z`)
   *
   * Always 20 ASCII chars long.
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

  /**
   * Parses an HTTP-date (RFC 9110 Section 5.6.7).
   * 
   * Supports IMF-fixdate (`"Sun, 06 Nov 1994 08:49:37 GMT"`), the obsolete
   * RFC 850 form (`"Sunday, 06-Nov-94 08:49:37 GMT"`), 
   * and asctime (`"Sun Nov  6 08:49:37 1994"`).
   *
   * Input is always UTC.
   *
   * - Returns: `nil` if `s` does not match one of the formats.
   */
  @inlinable
  init?(httpDateString s: String) {
    guard let tm = xsys.struct_tm(httpDateString: s) else { return nil }
    self = tm.utcTime
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


// MARK: - HTTP Date Parser Helpers

/// Two ASCII digits at `buf[offset ..< offset+2]`. `nil` on out-of-bounds or
/// non-digit input. Symmetric with ``writeTwoDigit``.
@inlinable
internal func parseTwoDigit(_ buf: UnsafeBufferPointer<UInt8>, at offset: Int)
              -> Int?
{
  guard offset >= 0, offset + 1 < buf.count else { return nil }
  let z  = UInt8(ascii: "0"), nine = UInt8(ascii: "9")
  let hi = buf[offset], lo = buf[offset + 1]
  guard hi >= z, hi <= nine, lo >= z, lo <= nine else { return nil }
  return Int(hi - z) * 10 + Int(lo - z)
}

/// Four ASCII digits at `buf[offset ..< offset+4]`. Symmetric with
/// ``writeFourDigit``.
@inlinable
internal func parseFourDigit(_ buf: UnsafeBufferPointer<UInt8>, at offset: Int)
              -> Int?
{
  guard let hi = parseTwoDigit(buf, at: offset),
        let lo = parseTwoDigit(buf, at: offset + 2) else { return nil }
  return hi * 100 + lo
}

/// `HH:MM:SS` at `buf[offset ..< offset+8]`.
@inlinable
internal func parseHMS(_ buf: UnsafeBufferPointer<UInt8>, at offset: Int)
              -> (Int, Int, Int)?
{
  let colon = UInt8(ascii: ":")
  guard offset + 7 < buf.count,
        let h = parseTwoDigit(buf, at: offset),
        buf[offset + 2] == colon,
        let m = parseTwoDigit(buf, at: offset + 3),
        buf[offset + 5] == colon,
        let s = parseTwoDigit(buf, at: offset + 6) else { return nil }
  return (h, m, s)
}

/// Index of `b0,b1,b2` in ``rfc1123MonthBytes`` (`0...11`), or `nil`.
@inlinable
internal func monthFromBytes(_ b0: UInt8, _ b1: UInt8, _ b2: UInt8) -> Int? {
  for i in 0..<12 {
    let m = rfc1123MonthBytes[i]
    if m.0 == b0 && m.1 == b1 && m.2 == b2 { return i }
  }
  return nil
}

/**
 * Pure RFC 9110 / RFC 7231 HTTP-date parser, byte-level.
 * Supports IMF-fixdate, the obsolete RFC 850 form, and asctime.
 */
@usableFromInline
internal func _parseHTTPDate(bytes buf: UnsafeBufferPointer<UInt8>)
              -> (year: Int, mon: Int, day: Int, h: Int, m: Int, sec: Int)?
{
  let comma = UInt8(ascii: ","), space = UInt8(ascii: " ")
  let dash  = UInt8(ascii: "-")

  if let ci = buf.firstIndex(of: comma) {
    // Skip the spaces after the comma.
    var off = ci + 1
    while off < buf.count && buf[off] == space { off += 1 }

    // Need at least "dd-Xxx-yy HH:MM:SS GMT" (22 bytes) past `off`.
    guard off + 21 < buf.count, let d = parseTwoDigit(buf, at: off) else {
      return nil 
    }
    let sep = buf[off + 2]

    if sep == dash { // RFC 850: dd-Xxx-yy HH:MM:SS GMT
      guard let mo = monthFromBytes(buf[off+3], buf[off+4], buf[off+5]),
            buf[off + 6] == dash, let y2 = parseTwoDigit(buf, at: off + 7),
            buf[off + 9] == space,
            let (hh, mm, ss) = parseHMS(buf, at: off + 10) else { return nil }
      let y = y2 + (y2 < 70 ? 2000 : 1900)
      return ( year: y, mon: mo, day: d, h: hh, m: mm, sec: ss )
    }

    if sep == space { // IMF: dd Xxx yyyy HH:MM:SS GMT (24 bytes past `off`)
      guard off + 23 < buf.count,
            let mo = monthFromBytes(buf[off+3], buf[off+4], buf[off+5]),
            buf[off + 6] == space, let y = parseFourDigit(buf, at: off + 7),
            buf[off + 11] == space,
            let (hh, mm, ss) = parseHMS(buf, at: off + 12) else { return nil }
      return ( year: y, mon: mo, day: d, h: hh, m: mm, sec: ss )
    }

    return nil
  }

  // asctime: "Xxx Xxx dd HH:MM:SS yyyy" (24 bytes). Day may be ` D` or `DD`.
  let z = UInt8(ascii: "0"), nine = UInt8(ascii: "9")
  guard buf.count >= 24, buf[3] == space,
        let mo = monthFromBytes(buf[4], buf[5], buf[6]),
        buf[7] == space else { return nil }
  
  let dh = buf[8], dl = buf[9]
  let day: Int
  if dh == space {
    guard dl >= z, dl <= nine else { return nil }
    day = Int(dl - z)
  }
  else if dh >= z, dh <= nine, dl >= z, dl <= nine {
    day = Int(dh - z) * 10 + Int(dl - z)
  }
  else { return nil }
  guard buf[10] == space, let (hh, mm, ss) = parseHMS(buf, at: 11),
        buf[19] == space,
        let y = parseFourDigit(buf, at: 20) else { return nil }
  
  return ( year: y, mon: mo, day: day, h: hh, m: mm, sec: ss )
}

/**
 * Pure ISO 8601 date(-time) parser, byte-level. Accepts a bare
 * `"YYYY-MM-DD"` date or a full `"YYYY-MM-DDTHH:MM:SS"` (with an
 * optional trailing `Z`); fractional seconds and numeric zone offsets
 * are ignored. Always interpreted as UTC. `mon` is 0-based to match
 * ``_parseHTTPDate`` and `tm_mon`.
 */
@usableFromInline
internal func _parseISO8601Date(bytes buf: UnsafeBufferPointer<UInt8>)
              -> (year: Int, mon: Int, day: Int, h: Int, m: Int, sec: Int)?
{
  let dash = UInt8(ascii: "-")
  guard buf.count >= 10, let y = parseFourDigit(buf, at: 0),
        buf[4] == dash, let mo = parseTwoDigit(buf, at: 5),
        buf[7] == dash, let d = parseTwoDigit(buf, at: 8),
        (1 ... 12).contains(mo), (1 ... 31).contains(d) else { return nil }

  // Optional "THH:MM:SS" (or space-separated) part.
  let t = UInt8(ascii: "T"), space = UInt8(ascii: " ")
  guard buf.count >= 19, buf[10] == t || buf[10] == space,
        let (hh, mm, ss) = parseHMS(buf, at: 11) else {
    return ( year: y, mon: mo - 1, day: d, h: 0, m: 0, sec: 0 )
  }
  return ( year: y, mon: mo - 1, day: d, h: hh, m: mm, sec: ss )
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

  /**
   * Parses an HTTP-date (RFC 9110 Section 5.6.7).
   * 
   * Supports IMF-fixdate (`"Sun, 06 Nov 1994 08:49:37 GMT"`), the obsolete
   * RFC 850 form (`"Sunday, 06-Nov-94 08:49:37 GMT"`),
   * and asctime (`"Sun Nov  6 08:49:37 1994"`).
   *
   * Only: `tm_year`, `tm_mon`, `tm_mday`, `tm_hour`, `tm_min`, `tm_sec`,
   * `tm_wday`, `tm_yday`, `tm_isdst`, ...) are zero.
   * 
   * Always UTC.
   */
  init?(httpDateString s: String) {
    var s = s
    guard let r = s.withUTF8({ _parseHTTPDate(bytes: $0) }) else { return nil }

    self.init()
    self.tm_year = Int32(r.year - 1900)
    self.tm_mon  = Int32(r.mon)
    self.tm_mday = Int32(r.day)
    self.tm_hour = Int32(r.h)
    self.tm_min  = Int32(r.m)
    self.tm_sec  = Int32(r.sec)
  }

  /**
   * Parses an ISO 8601 date or date-time, e.g. `"2026-05-17"` or
   * `"2026-05-17T12:34:56Z"`. Fractional seconds and numeric zone
   * offsets are ignored and the value is treated as UTC. Symmetric
   * with ``iso8601String``. Returns nil if `s` is not a valid date.
   */
  init?(iso8601String s: String) {
    var s = s
    guard let r = s.withUTF8({ _parseISO8601Date(bytes: $0) }) else {
      return nil
    }

    self.init()
    self.tm_year = Int32(r.year - 1900)
    self.tm_mon  = Int32(r.mon)
    self.tm_mday = Int32(r.day)
    self.tm_hour = Int32(r.h)
    self.tm_min  = Int32(r.m)
    self.tm_sec  = Int32(r.sec)
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

  /**
   * Optimized version that produces HTTP date strings (RFC 1123).
   *
   * E.g. "Sun, 17 May 2026 12:34:56 GMT". Always 29 ASCII chars long.
   */
  @inlinable
  var httpDateString : String { utcTime.httpDateString }

  /**
   * Produce ISO UTC date strings (e.g. `2026-05-17T12:34:56Z`)
   *
   * Always 20 ASCII chars long.
   */
  @inlinable
  var iso8601String : String { utcTime.iso8601String }

  /// Example `strftime` format (`man strftime`):
  ///   "%a, %d %b %Y %H:%M:%S GMT"
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
