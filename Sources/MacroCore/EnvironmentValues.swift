//
//  EnvironmentValues.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

/**
 * A protocol describing a value which can be put into a `Macro` environment
 * (`EnvironmentValue`'s).
 * The sole purpose is to avoid stringly typed environment keys (like
 * "")
 *
 * Example:
 *
 *     enum LoginUserEnvironmentKey: EnvironmentKey {
 *       static let defaultValue = ""
 *     }
 *
 * In addition to the key definition, one usually declares an accessor to the
 * respective environment holder, for example the `IncomingMessage`:
 *
 *     extension IncomingMessage {
 *
 *       var loginUser : String {
 *         set { self[LoginUserEnvironmentKey.self] = newValue }
 *         get { self[LoginUserEnvironmentKey.self] }
 *       }
 *     }
 *
 * It can then be used like:
 *
 *     app.use { req, res, next in
 *       console.log("active user:", req.loginUser)
 *       next()
 *     }
 *
 * If the value really is optional, it can be declared an optional:
 *
 *     enum DatabaseConnectionEnvironmentKey: EnvironmentKey {
 *       static let defaultValue : DatabaseConnection?
 *     }
 *
 * To add a shorter name for environment dumps, implement the `loggingKey`
 * property:
 *
 *     enum DatabaseConnectionEnvironmentKey: EnvironmentKey {
 *       static let defaultValue : DatabaseConnection? = nil
 *       static let loggingKey   = "db"
 *     }
 *
 */
public protocol EnvironmentKey {
  
  associatedtype Value
  
  /**
   * If a value isn't set in the environment, the `defaultValue` will be
   * returned.
   */
  static var defaultValue: Self.Value { get }
  
  /**
   * The logging key is used when the environment is logged into a string.
   * (It defaults to the Swift runtime name of the implementing type).
   */
  static var loggingKey : String { get }
}

public extension EnvironmentKey {
  
  @inlinable
  static var loggingKey : String {
    return String(describing: self)
  }
}

/**
 * A dictionary which can hold values assigned to `EnvironmentKey`s.
 *
 * This is a way to avoid stringly typed `extra` APIs by making use of type
 * identity in Swift.
 * In Node/JS you would usually just attach properties to the `IncomingMessage`
 * object.
 *
 * To drive `EnvironmentValues`, `EnvironmentKey`s need to be defined. Since
 * the type of an `EnviromentKey` is globally unique within Swift, it can be
 * used to key into the structure to the store the associated value.
 *
 * Note that in APIs like SwiftUI or SwiftBlocksUI, EnvironmentValues are
 * usually "stacked" in the hierarchy of Views or Blocks.
 * That's not necessarily the case in Macro, though Macro application can also
 * use it like that.
 */
@frozen public struct EnvironmentValues {
  
  public static let empty = EnvironmentValues()
  
  @usableFromInline
  var values = [ ObjectIdentifier : ( loggingKey: String, value: Any ) ]()
  
  @inlinable
  public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
    set {
      values[ObjectIdentifier(key)] = ( K.loggingKey, newValue )
    }
    get {
      guard let value = values[ObjectIdentifier(key)]?.value else {
        return K.defaultValue
      }
      guard let typedValue = value as? K.Value else {
        assertionFailure("unexpected typed value: \(value)")
        return K.defaultValue
      }
      return typedValue
    }
  }
  
  public var loggingDictionary : [ String : Any ] {
    var dict = [ String : Any ]()
    dict.reserveCapacity(values.count)
    for ( key, value ) in values.values {
      dict[key] = value
    }
    return dict
  }
}

public protocol EnvironmentValuesHolder {
  
  var environment : EnvironmentValues { set get }
  
  subscript<K: EnvironmentKey>(key: K.Type) -> K.Value { set get }
}

public extension EnvironmentValuesHolder {
  
  @inlinable
  subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
    set { environment[key] = newValue }
    get { return environment[key] }
  }
}
