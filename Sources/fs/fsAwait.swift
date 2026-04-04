// AsyncAwait.swift -- fs
//
// Swift async/await wrappers for callback-based fs functions.

import xsys
import struct MacroCore.Buffer

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

/// Read entire file contents as a ``Buffer``.
@inlinable
public func readFile(_ path: String) async throws -> Buffer {
  try await asyncValue(FSError.readFailed(path)) {
    readFile(path, yield: $0)
  }
}

/// Write a ``Buffer`` to a file.
@inlinable
public func writeFile(_ path: String, _ data: Buffer) async throws {
  try await asyncVoid { writeFile(path, data, whenDone: $0) }
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

/// Create a directory (async).
@inlinable
public func mkdir(_ path: String, _ options: MakeDirOptions = .init())
              async throws
{
  try await asyncVoid { mkdir(path, options, yield: $0) }
}

/// Remove a directory (async).
@inlinable
public func rmdir(_ path: String) async throws {
  try await asyncVoid { rmdir(path, yield: $0) }
}

/// Delete a file (async).
@inlinable
public func unlink(_ path: String) async throws {
  try await asyncVoid { unlink(path, yield: $0) }
}

/// Rename a file or directory (async).
@inlinable
public func rename(_ oldPath: String, _ newPath: String) async throws {
  try await asyncVoid {
    rename(oldPath, newPath, yield: $0)
  }
}

// MARK: - Errors

public enum FSError: Error {

  case readFailed(String)
  case statFailed(String)
}
