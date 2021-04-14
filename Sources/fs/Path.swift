//
//  Path.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/8/16.
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//

#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc
#else
  import Darwin
#endif

#if canImport(Foundation)
  import struct Foundation.URL
  import class  Foundation.FileManager
#endif

public enum PathModule {}
public typealias path = PathModule

public extension PathModule {
  
  @inlinable
  static func basename(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let sp = rindex(cs, 47 /* / */)
      guard sp != nil else { return path }
      let bn = sp! + 1
      return String(cString: bn)
    }
  }
  
  @inlinable
  static func dirname(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let sp = UnsafePointer<CChar>(rindex(cs, 47 /* / */))
      guard sp != nil else { return path }
      let len = sp! - cs
      return String.fromCString(cs, length: len)!
    }
  }
    
  @inlinable
  static func join(_ components: String...) -> String {
    guard !components.isEmpty else { return "" }
    if components.count == 1 { return components[0] }
    
    #if canImport(Foundation)
      var base = URL(fileURLWithPath: components[0])
      for component in components.dropFirst() {
        guard !component.isEmpty else { continue }
        base.appendPathComponent(component)
      }
      return base.path
    #else
      #if os(Windows)
        return components.joined(separator: "\\")
      #else
        return components.joined(separator: "/")
      #endif
    #endif
  }

  #if canImport(Foundation)
    // https://nodejs.org/api/path.html#path_path_resolve_paths
    @inlinable
    static func resolve(_ paths: String...) -> String {
      guard !paths.isEmpty else { return "" }
      
      func buildPath(_ pathURL: URL, with components: [ String ]) -> String {
        var pathURL = pathURL
        components.forEach { pathURL.appendPathComponent($0) }
        var path = pathURL.path
        while path.hasSuffix("/") { path.removeLast() }
        return path
      }
      
      var components = [ String ]()
      components.reserveCapacity(paths.count)
      for path in paths.reversed() {
        guard !path.isEmpty else { continue }
        let pathURL = URL(fileURLWithPath: path).standardizedFileURL
        if pathURL.path.hasPrefix("/") { // found absolute URL
          return buildPath(pathURL, with: components)
        }
        else {
          components.append(path)
        }
      }
      let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      return buildPath(cwd, with: components)
  }
  #endif
}


// MARK: - CString

extension String {
  
  // FIXME: This is probably not necessary anymore?
  @usableFromInline
  static func fromCString(_ cs: UnsafePointer<CChar>, length olength: Int?)
              -> String? 
  {
    guard let length = olength else { // no length given, use \0 std imp
      return String(validatingUTF8: cs)
    }
    
    let buflen = length + 1
    let buf    = UnsafeMutablePointer<CChar>.allocate(capacity: buflen)
    memcpy(buf, cs, length)
    buf[length] = 0 // zero terminate

    let s = String(validatingUTF8: buf)
    buf.deallocate()
    return s
  }
}
