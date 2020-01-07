//
//  Macro.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

@_exported import func     MacroCore.nextTick
@_exported import func     MacroCore.setTimeout
@_exported import enum     MacroCore.console
@_exported import enum     MacroCore.process
@_exported import func     MacroCore.concat
@_exported import enum     MacroCore.JSON
@_exported import enum     MacroCore.ReadableError
@_exported import enum     MacroCore.WritableError
@_exported import struct   NIO.ByteBuffer
@_exported import protocol NIO.EventLoop
@_exported import protocol NIO.EventLoopGroup

// To support the pipe (`|`) operators. Swift can't re-export operators?
@_exported import MacroCore

import enum      fs.FileSystemModule
public typealias fs = FileSystemModule
import enum      fs.PathModule
public typealias path = PathModule
import enum      fs.JSONFileModule
public typealias jsonfile = JSONFileModule

import enum      http.HTTPModule
public typealias http = HTTPModule
import enum      http.BasicAuthModule
public typealias basicAuth = BasicAuthModule

public var argv : [ String ]          { return process.argv }
public var env  : [ String : String ] { return process.env  }
