//
//  Object.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public enum Object {}

public extension Object {

  @inlinable
  static func keys<K, V>(_ dictionary: [ K : V ]) -> [ K ] {
    return Array(dictionary.keys)
  }

  @inlinable
  static func keys<V>(_ array: [ V ]) -> [ Int ] {
    return Array(array.indices)
  }
  
  @inlinable
  static func keys(_ object: Any) -> [ String ] {
    return Mirror(reflecting: object).children.compactMap { label, _ in
      return label
    }
  }

  @inlinable
  static func entries<K, V>(_ dictionary: [ K : V ]) -> [ ( K, V ) ] {
    return Array(dictionary)
  }

  @inlinable
  static func entries<V>(_ array: [ V ]) -> [ ( Int, V ) ] {
    return Array(array.enumerated())
  }
  
  @inlinable
  static func entries(_ object: Any) -> [ ( String, Any ) ] {
    return Mirror(reflecting: object).children.compactMap { label, value in
      guard let label = label else { return nil }
      return ( label, value )
    }
  }

  @inlinable
  static func values<K, V>(_ dictionary: [ K : V ]) -> [ V ] {
    return Array(dictionary.values)
  }

  @inlinable
  static func values<V>(_ array: [ V ]) -> [ V ] {
    return array
  }
  
  @inlinable
  static func values(_ object: Any) -> [ Any ] {
    return Mirror(reflecting: object).children
             .filter { $0.label != nil }
             .map    { $0.value }
  }
}
