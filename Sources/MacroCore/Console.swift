//
//  Console.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct Logging.Logger

/**
 * Just a small JavaScript like `console` shin around the Swift Logging API.
 */
public enum console {
  
  public static let logger = Logger(label: "μ.console")
  
  @usableFromInline
  @inline(__always)
  internal static func string(for msg: String, _ values: [ Any? ])
                       -> Logger.Message
  {
    var message = msg
    for value in values {
      if let value = value {
        message.append(" ")
        if let s = value as? String {
          message.append(s)
        }
        else if let s = value as? CustomStringConvertible {
          message.append(s.description)
        }
        else {
          message.append("\(value)")
        }
      }
      else {
        message.append(" <nil>")
      }
    }
    return Logger.Message(stringLiteral: message)
  }
  
  @inlinable
  public static func error(_ msg: @autoclosure () -> String, _ values : Any?...)
  {
    logger.error(string(for: msg(), values))
  }
  @inlinable
  public static func warn (_ msg: @autoclosure () -> String, _ values : Any?...) {
    logger.warning(string(for: msg(), values))
  }
  @inlinable
  public static func log  (_ msg: @autoclosure () -> String, _ values : Any?...) {
    logger.notice(string(for: msg(), values))
  }
  @inlinable
  public static func info (_ msg: @autoclosure () -> String, _ values : Any?...) {
    logger.info(string(for: msg(), values))
  }
  @inlinable
  public static func trace(_ msg: @autoclosure () -> String, _ values : Any?...) {
    logger.trace(string(for: msg(), values))
  }

  @inlinable
  public static func dir(_ obj: Any?) {
    // TBD: rather dump to a String, and then send to the log?
    if let obj = obj {
      dump(obj)
    }
    else {
      print("<nil>")
    }
  }
}
