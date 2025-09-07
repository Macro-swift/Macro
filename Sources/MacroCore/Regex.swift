//
//  Regex.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021-2025 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
import class  Foundation.NSRegularExpression
import class  Foundation.NSString
import struct Foundation.NSRange

public extension String {
  /*
   * FIXME(2025-08-30): We do have Regex syntax in Swift now, at least 
   *                    optionally.
   */

  /**
   * This is used to replicate those:
   * ```javascript
   * arg.match(/^-/)
   * ```
   *
   * TODO: `g` and `i` suffixes, don't know about `g`, but `i` is an option:
   * ```javascript
   * arg.match("ain", .caseInsensitive)
   * ```
   *
   * Note: Like JS this returns `nil` if no matches are found.
   */
  @inlinable
  func match(_ pattern: String,
             options: NSRegularExpression.Options = [])
       -> [ String ]?
  {
    guard let regex =
                try? NSRegularExpression(pattern: pattern, options: options)
    else {
      assertionFailure("Could not parse regex: \(pattern)")
      return nil
    }
    let range   = NSRange(self.startIndex..<self.endIndex, in: self)
    let matches = regex.matches(in: self, options: [], range: range)
    if matches.isEmpty { return nil }
    
    let nsSelf       = self as NSString
    var matchStrings = [ String ]()
    matchStrings.reserveCapacity(matches.count)
    
    for match in matches {
      let matchString = nsSelf.substring(with: match.range)
      matchStrings.append(matchString)
    }
    return matchStrings
  }
  
  /**
   * This is used to replicate those:
   * ```javascript
   * arg.replace(/^-+/, "")
   * searchPath.replace(/\\/g, "\\\\"))
   * ```
   * TODO: What about `g`, what is that in NSRegEx? An option?
   * 
   */
  @inlinable
  func replace(_ pattern: String, _ replacement: String,
               options: NSRegularExpression.Options = []) -> String
  {
    guard let regex =
                try? NSRegularExpression(pattern: pattern, options: options)
    else {
      assertionFailure("Could not parse regex: \(pattern)")
      return self
    }
    let range  = NSRange(self.startIndex..<self.endIndex, in: self)
    return regex.stringByReplacingMatches(in: self, options: [], range: range,
                                          withTemplate: replacement)
  }

  /**
   * This is used to replicate those:
   * ```javascript
   * arg.split(/^-+/, "")
   * searchPath.split(/\\/g, "\\\\"))
   * ```
   *
   * TODO: What about `g`, what is that in NSRegEx? An option?
   */
  @inlinable
  func split(_ pattern: String, omitEmpty: Bool = false) -> [ String ] {
    guard !self.isEmpty else { return [ "" ] } // That's what Node does
    
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [])
    else {
      assertionFailure("Could not parse regex: \(pattern)")
      return [ self ]
    }
    
    let range   = NSRange(self.startIndex..<self.endIndex, in: self)
    let matches = regex.matches(in: self, options: [], range: range)
    guard !matches.isEmpty else { return [ self ] }

    let nsSelf     = self as NSString
    var idx        = 0
    var components = [ String ]()
    components.reserveCapacity(matches.count + 1)
    
    for match in matches {
      let splitterRange = match.range
      let componentRange = NSRange(location: idx,
                                   length: splitterRange.location - idx)
      
      assert(idx >= 0 && idx < nsSelf.length)
      assert(componentRange.length  >= 0)
      assert(componentRange.location > 0)
      let component = nsSelf.substring(with: componentRange)
      if !omitEmpty || !component.isEmpty { components.append(component) }
      
      idx = splitterRange.upperBound
    }
    
    if idx + 1 < nsSelf.length {
      let component = nsSelf.substring(from: idx)
      if !omitEmpty || !component.isEmpty { components.append(component) }
    }
    
    return components
  }
}
#endif // canImport(Foundation)
