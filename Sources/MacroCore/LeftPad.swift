//
//  LeftPad.swift
//  MacroCore
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * An awesome module following the leads of [left-pad](http://left-pad.io).
 */
public enum LeftPadModule {}

public extension LeftPadModule {

  @inlinable
  static func leftpad(_ string: String, _ length: Int,
                      _ paddingCharacter: Character = " ") -> String
  {
    let count = string.count
    guard count < length else { return string }
    let padCount = length - count
    return String(repeating: paddingCharacter, count: padCount) + string
  }
}

@inlinable
public func leftpad(_ string: String, _ length: Int,
                    _ paddingCharacter: Character = " ") -> String
{
  return LeftPadModule.leftpad(string, length, paddingCharacter)
}

public extension String {
  
  @inlinable
  func padStart(_ targetLength: Int, _ padString: String = " ") -> String {
    return _pad(targetLength: targetLength, padString: padString) { $0 + self }
  }
  
  @inlinable
  func padEnd(_ targetLength: Int, _ padString: String = " ") -> String {
    return _pad(targetLength: targetLength, padString: padString) { self + $0 }
  }
  
  @usableFromInline
  internal func _pad(targetLength: Int, padString: String = " ",
                     combine: ( Substring ) -> String) -> String {
    let count = self.count
    guard count < targetLength else { return self }
    
    // That is so complex it might actually deserve a test :->
    let missingChars = targetLength - count
    let padWidth     = padString.count
    let padCount     = (missingChars % padWidth == 0)
                     ? (missingChars / padWidth)
                     : (missingChars / padWidth) + 1
    let dropCount    = padCount * padWidth - missingChars
    let padder       = String(repeating: padString, count: padCount)
                         .dropLast(dropCount)
    return combine(padder)
  }
}
