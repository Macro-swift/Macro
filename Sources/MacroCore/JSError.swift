//
//  JSError.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

/**
 * A simple Error similar to the JavaScript error.
 */
public struct JSError: Swift.Error {
  
  public var name       : String
  public var message    : String
  public var fileName   : StaticString
  public var lineNumber : Int

  public init(_ name: String, _ message: String = "",
              fileName: StaticString = #file, lineNumber: Int = #line)
  {
    self.name       = name
    self.message    = message
    self.fileName   = fileName
    self.lineNumber = lineNumber
  }
}
