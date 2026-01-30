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
    let slashASCII : Int32 = 47 /* / */
    return path.withCString { cs in
      let sp = rindex(cs, slashASCII)
      guard let sp2 = sp else { return path }
      return String(cString: sp2 + 1)
    }
  }
  @inlinable
  static func basename(_ path: String, _ dropExtension: String) -> String {
    let base = basename(path)
    guard base.hasSuffix(dropExtension) else { return base }
    return String(base.dropLast(dropExtension.count))
  }
  
  @inlinable
  static func dirname(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let slashASCII : Int32 = 47 /* / */
      let sp = UnsafePointer<CChar>(rindex(cs, slashASCII))
      guard let sp2 = sp else { return path }
      let len = sp2 - cs
      return String.fromCString(cs, length: len)!
    }
  }
  
  /**
   * Returns the last extension in the path.
   * 
   * Behaviour:
   * - "home"        => ""
   * - "folder/home" => ""
   * - ".gitignore"  => ""  // leading dot, not an extension
   * - "archive."    => "." // trailing dot, extension
   */
  @inlinable
  static func extname(_ path: String) -> String {
    // TODO: this doesn't deal proper with trailing slashes
    return path.withCString { cs in
      let dotASCII   : Int32 = 46 /* . */
      let slashASCII : Int32 = 47 /* / */

      guard let dotPtr = UnsafePointer<CChar>(rindex(cs, dotASCII)) else {
        return "" // no dot => ""
      }
      if let slashPtr = UnsafePointer<CChar>(rindex(cs, slashASCII)) {
        assert(dotPtr != slashPtr)
        
        if slashPtr > dotPtr { // no dot in basename
          return String(cString: slashPtr + 1)          
        }
        if slashPtr + 1 == dotPtr { // leading dot, not an extension
          return ""
        }
      }
      else { // no slash, only dot
        if cs == dotPtr { return "" } // leading dot, not an extension
      }
      return String(cString: dotPtr)
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
