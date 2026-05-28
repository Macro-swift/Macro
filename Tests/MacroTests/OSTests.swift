import XCTest
@testable import MacroCore
@testable import fs

final class OSTests: XCTestCase {

  override class func setUp() {
    disableAtExitHandler()
    super.setUp()
  }

  func testTmpdirReturnsNonEmptyPath() {
    let dir = OSModule.tmpdir()
    XCTAssertFalse(dir.isEmpty)
    if let env = process.env["TMPDIR"], !env.isEmpty {
      XCTAssertTrue(env.hasPrefix(dir) || env == dir + "/")
    }
    else {
      XCTAssertTrue(dir == "/tmp" || dir.hasPrefix("/"))
    }
  }

  func testTmpdirStripsTrailingSeparator() {
    let saved = process.env["TMPDIR"]
    addTeardownBlock {
      if let saved = saved { setenv("TMPDIR", saved, 1) }
      else { unsetenv("TMPDIR") }
    }
    setenv("TMPDIR", "/var/tmp/", 1)
    XCTAssertEqual(OSModule.tmpdir(), "/var/tmp")
  }

  func testMkdtempAsyncCreatesUniqueDirectory() async throws {
    let prefix = OSModule.tmpdir() + "/macro-os-await-"
    let a = try await mkdtemp(prefix)
    let b = try await mkdtemp(prefix)
    addTeardownBlock {
      try? rmdirSync(a)
      try? rmdirSync(b)
    }
    XCTAssertNotEqual(a, b)
    XCTAssertTrue(a.hasPrefix(prefix))
    XCTAssertEqual(a.count, prefix.count + 6)
    XCTAssertTrue(FileSystemModule.existsSync(a))
    XCTAssertTrue(FileSystemModule.existsSync(b))
  }

  func testMkdtempSyncCreatesUniqueDirectory() throws {
    let prefix = OSModule.tmpdir() + "/macro-os-test-"
    let a = try mkdtempSync(prefix)
    let b = try mkdtempSync(prefix)
    addTeardownBlock {
      try? rmdirSync(a)
      try? rmdirSync(b)
    }
    XCTAssertNotEqual(a, b)
    XCTAssertTrue(a.hasPrefix(prefix))
    XCTAssertEqual(a.count, prefix.count + 6) // six random chars
    XCTAssertTrue(FileSystemModule.existsSync(a))
    XCTAssertTrue(FileSystemModule.existsSync(b))
  }

  func testHomedir() {
    let h = OSModule.homedir()
    XCTAssertFalse(h.isEmpty)
    #if !os(Windows)
    XCTAssertTrue(h.hasPrefix("/"), "expected POSIX absolute path, got \(h)")
    #endif
    if let env = process.env["HOME"], !env.isEmpty { XCTAssertEqual(h, env) }
  }

  func testHostname() {
    let n = OSModule.hostname()
    // gethostname can fail in sandboxed envs; allow empty but if set, no
    // embedded NULs and no excessive length.
    XCTAssertFalse(n.contains("\0"))
    XCTAssertLessThan(n.count, 256)
  }

  func testPlatform() {
    let p = OSModule.platform()
    XCTAssertFalse(p.isEmpty)
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    XCTAssertEqual(p, "darwin")
    #elseif os(Linux)
    XCTAssertEqual(p, "linux")
    #elseif os(Windows)
    XCTAssertEqual(p, "win32")
    #endif
  }

  func testType() {
    let t = OSModule.type()
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    XCTAssertEqual(t, "Darwin")
    #elseif os(Linux)
    XCTAssertEqual(t, "Linux")
    #elseif os(Windows)
    XCTAssertEqual(t, "Windows_NT")
    #endif
  }

  func testArch() {
    let a = OSModule.arch()
    XCTAssertFalse(a.isEmpty)
    #if arch(arm64)
    XCTAssertEqual(a, "arm64")
    #elseif arch(x86_64)
    XCTAssertEqual(a, "x64")
    #endif
  }

  func testEndianness() {
    let e = OSModule.endianness()
    XCTAssertTrue(e == "LE" || e == "BE")
    // All currently-supported Swift platforms are little-endian.
    XCTAssertEqual(e, "LE")
  }

  func testEOL() {
    #if os(Windows)
    XCTAssertEqual(OSModule.EOL, "\r\n")
    #else
    XCTAssertEqual(OSModule.EOL, "\n")
    #endif
  }

  func testDevNull() {
    #if os(Windows)
    XCTAssertEqual(OSModule.devNull, #"\\.\nul"#)
    #else
    XCTAssertEqual(OSModule.devNull, "/dev/null")
    #endif
  }

  static let allTests = [
    ( "testTmpdirReturnsNonEmptyPath"     , testTmpdirReturnsNonEmptyPath     ),
    ( "testTmpdirStripsTrailingSeparator" , testTmpdirStripsTrailingSeparator ),
    ( "testHomedir"                       , testHomedir                       ),
    ( "testHostname"                      , testHostname                      ),
    ( "testPlatform"                      , testPlatform                      ),
    ( "testType"                          , testType                          ),
    ( "testArch"                          , testArch                          ),
    ( "testEndianness"                    , testEndianness                    ),
    ( "testEOL"                           , testEOL                           ),
    ( "testDevNull"                       , testDevNull                       ),
    ( "testMkdtempSyncCreatesUniqueDirectory", 
      testMkdtempSyncCreatesUniqueDirectory ),
  ]
}
