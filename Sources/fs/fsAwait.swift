// AsyncAwait.swift -- fs
//
// Swift async/await wrappers for callback-based fs functions.

import xsys
import struct MacroCore.Buffer
#if canImport(Foundation)
  import struct Foundation.Data
#endif

// Note: Those would probably change if we start using NIOFileSystem.
// But NIOFileSystem is async/await, so that would also be quite a bit of extra
// hopping (jump from eventloop to async pool, then jump into the backing 
// thread?)

// MARK: - Continuation Helpers

@inlinable
func asyncValue<T>(_ fallback: Error,
                    _ fn: (@escaping (Error?, T?) -> Void) -> Void)
       async throws -> T
{
  try await withCheckedThrowingContinuation { cont in
    fn { err, val in
      if let err { cont.resume(throwing: err) }
      else if let val { cont.resume(returning: val) }
      else { cont.resume(throwing: fallback) }
    }
  }
}

@inlinable
func asyncVoid(_ fn: (@escaping (Error?) -> Void) -> Void) async throws {
  try await withCheckedThrowingContinuation {
    (cont: CheckedContinuation<Void, Error>) in
    fn { err in
      if let err { cont.resume(throwing: err) }
      else { cont.resume() }
    }
  }
}

// MARK: - Await Wrappers

/// Read entire file contents.
@inlinable
public func readFile(_ path: String) async throws -> Buffer {
  try await asyncValue(FSError.readFailed(path)) {
    readFile(path, yield: $0)
  }
}

/// Read entire file contents.
@inlinable
public func readFile(_ path: String, _ encoding: String.Encoding)
              async throws -> String
{
  try await asyncValue(FSError.readFailed(path)) {
    readFile(path, encoding, yield: $0)
  }
}

/// Read entire file contents.
@inlinable
public func readFile(_ path: String, _ encoding: String)
              async throws -> String
{
  try await readFile(path, .encodingWithName(encoding))
}

/// Write a ``Buffer`` to a file.
@inlinable
public func writeFile(_ path: String, _ data: Buffer) async throws {
  try await asyncVoid { writeFile(path, data, whenDone: $0) }
}

#if canImport(Foundation)
/// Write `Data` to a file.
@inlinable
public func writeFile(_ path: String, _ data: Data) async throws {
  try await asyncVoid { writeFile(path, data, whenDone: $0) }
}
#endif

/// Write a `String` to a file.
@inlinable
public func writeFile(_ path: String, _ string: String,
                      _ encoding: String.Encoding = .utf8)
              async throws
{
  try await asyncVoid { writeFile(path, string, encoding, whenDone: $0) }
}

/// Write a `String` to a file.
@inlinable
public func writeFile(_ path: String, _ string: String, _ encoding: String)
  async throws
{
  try await asyncVoid { writeFile(path, string, encoding, whenDone: $0) }
}

/// Stat a file.
@inlinable
public func stat(_ path: String) async throws -> xsys.stat_struct {
  try await asyncValue(FSError.statFailed(path)) {
    stat(path, yield: $0)
  }
}

/// List directory entries.
@inlinable
public func readdir(_ path: String) async throws -> [ String ] {
  let entries: [ String ]? = try await asyncValue(FSError.readFailed(path)) {
    readdir(path, yield: $0) 
  }
  return entries ?? []
}

/// Create a directory
@inlinable
public func mkdir(_ path: String, _ options: MakeDirOptions = .init())
              async throws
{
  try await asyncVoid { mkdir(path, options, yield: $0) }
}

/// Remove a directory
@inlinable
public func rmdir(_ path: String) async throws {
  try await asyncVoid { rmdir(path, yield: $0) }
}

/// Delete a file.
@inlinable
public func unlink(_ path: String) async throws {
  try await asyncVoid { unlink(path, yield: $0) }
}

/// Rename a file or directory.
@inlinable
public func rename(_ oldPath: String, _ newPath: String) async throws {
  try await asyncVoid {
    rename(oldPath, newPath, yield: $0)
  }
}

public extension FileSystemModule {

  @inlinable
  static func readFile(_ path: String) async throws -> Buffer {
    try await fs.readFile(path)
  }
  @inlinable
  static func readFile(_ path: String, _ encoding: String.Encoding)
                async throws -> String
  {
    try await fs.readFile(path, encoding)
  }
  @inlinable
  static func readFile(_ path: String, _ encoding: String)
                async throws -> String
  {
    try await fs.readFile(path, encoding)
  }

  @inlinable
  static func writeFile(_ path: String, _ data: Buffer) async throws {
    try await fs.writeFile(path, data)
  }
  
  #if canImport(Foundation)
  @inlinable
  static func writeFile(_ path: String, _ data: Data) async throws {
    try await fs.writeFile(path, data)
  }
  #endif
  
  @inlinable
  static func writeFile(_ path: String, _ string: String,
                        _ encoding: String.Encoding = .utf8) async throws
  {
    try await fs.writeFile(path, string, encoding)
  }
  @inlinable
  static func writeFile(_ path: String, _ string: String, _ encoding: String) 
    async throws
  {
    try await fs.writeFile(path, string, encoding)
  }

  @inlinable
  static func stat(_ path: String) async throws -> xsys.stat_struct {
    try await fs.stat(path)
  }

  @inlinable
  static func readdir(_ path: String) async throws -> [ String ] {
    try await fs.readdir(path)
  }

  @inlinable
  static func mkdir(_ path: String, _ options: MakeDirOptions = .init())
                async throws
  {
    try await fs.mkdir(path, options)
  }
  @inlinable
  static func rmdir(_ path: String) async throws {
    try await fs.rmdir(path)
  }
  @inlinable
  static func unlink(_ path: String) async throws {
    try await fs.unlink(path)
  }
  @inlinable
  static func rename(_ oldPath: String, _ newPath: String) async throws {
    try await fs.rename(oldPath, newPath)
  }
}

// MARK: - Errors

public enum FSError: Error {

  case readFailed(String)
  case statFailed(String)
}
