//
//  Agent.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * TODO:
 * This eventually should also support Async HTTP Client and allow the framework
 * consumer to select the Agent backend.
 * The switching could be done by either making `Agent` a function, or by
 * creating a `Agent` class with distinct backends.
 *
 * For AHC we might want to tie `globalAgent` to an eventloop (i.e. thread).
 */

public typealias Agent = URLSessionAgent

public extension HTTPModule {

  static var globalAgent = Agent(options: .init())
 
}
