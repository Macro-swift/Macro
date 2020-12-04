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
@_exported import enum     MacroCore.JSONModule
@_exported import enum     MacroCore.ReadableError
@_exported import enum     MacroCore.WritableError
@_exported import struct   MacroCore.Buffer
@_exported import func     MacroCore.leftpad
@_exported import protocol NIO.EventLoop
@_exported import protocol NIO.EventLoopGroup
@_exported import struct   Logging.Logger
@_exported import func     MacroCore.__dirname

// To support the pipe (`|`) operators. Swift can't re-export operators?
@_exported import MacroCore

// MARK: - Submodules in `fs` Target

import enum      fs.FileSystemModule
import enum      fs.PathModule
import enum      fs.JSONFileModule
public typealias fs       = FileSystemModule
public typealias path     = PathModule
public typealias jsonfile = JSONFileModule

// MARK: - Submodules in `http` Target

import enum      http.HTTPModule
import enum      http.BasicAuthModule
import enum      http.QueryStringModule
public typealias http        = HTTPModule
public typealias basicAuth   = BasicAuthModule
public typealias querystring = QueryStringModule

// MARK: - Process stuff

public var argv : [ String ]          { return process.argv }
public var env  : [ String : String ] { return process.env  }
