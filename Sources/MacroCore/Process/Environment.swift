//
//  Environment.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import class Foundation.ProcessInfo

public extension process { // Environment
  
  /**
   * Returns the environment variables of the process.
   *
   * This hooks into `Foundation.processInfo`, it doesn't maintain an own
   * cache.
   */
  @inlinable
  static var env  : [ String : String ] {
    return ProcessInfo.processInfo.environment
  }
}

// MARK: - Helpers

public extension process {
  
  /**
   * Checks for an integer environment variable.
   *
   * - Parameter environmentVariableName: The name of the environment variable.
   * - Parameter defaultValue: Returned if the variable isn't set or can't be
   *                           parsed.
   * - Parameter lowerWarningBound: If the value set is below this optional
   *                                value, a warning will be logged to the
   *                                console.
   * - Parameter upperWarningBound: If the value set is above this optional
   *                                value, a warning will be logged to the
   *                                console.
   * - Returns: the integer value of the environment variable, or the
   *            `defaultValue` if the environment variable wasn't set.
   */
  @inlinable
  static func getenv(_ environmentVariableName : String,
                     defaultValue         : Int,
                     lowerWarningBound    : Int? = nil,
                     upperWarningBound    : Int? = nil) -> Int
  {
    if let s = process.env[environmentVariableName], !s.isEmpty {
      guard let value = Int(s), value > 0 else {
        console.error("invalid int value in env \(environmentVariableName):", s)
        return defaultValue
      }
      if let wv = lowerWarningBound, value < wv {
        console.warn("pretty small \(environmentVariableName) value:", value)
      }
      if let wv = upperWarningBound, value > wv {
        console.warn("pretty large \(environmentVariableName) value:", value)
      }
      return value
    }
    else {
      return defaultValue
    }
  }
  
  /**
   * Checks for an boolean environment variable.
   *
   * - Parameter environmentVariableName: The name of the environment variable.
   * - Returns: False if the variable is not set, or none of the predefined
   *            strings: `1`, `true`, `YES` or `enabled`.
   */
  @inlinable
  static func getenvflag(_ environmentVariableName: String) -> Bool {
    guard let s = process.env[environmentVariableName], !s.isEmpty else {
      return false
    }
    return s == "1" || s == "true" || s == "YES" || s == "enabled"
  }
}
