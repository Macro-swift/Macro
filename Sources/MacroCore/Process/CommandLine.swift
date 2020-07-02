//
//  CommandLine.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public extension process { // CommandLine
  
  @inlinable
  static var argv : [ String ] { return CommandLine.arguments }
}
