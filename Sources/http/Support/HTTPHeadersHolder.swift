//
//  HTTPHeadersHolder.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

import struct NIOHTTP1.HTTPHeaders

public protocol HTTPHeadersHolder: AnyObject {
  var headers : HTTPHeaders { get }
}
public protocol HTTPMutableHeadersHolder: HTTPHeadersHolder {
  var headers : HTTPHeaders { get set }
}

// MARK: - Express API

public extension HTTPHeadersHolder {
  
  /**
   * Returns the value of a header, or nil if the header is empty.
   * 
   * If there are multiple headers w/ the same name, their value is joined
   * by ", ", e.g.:
   * ```http
   * Accept: text/html
   * Accept: application/json
   * ```
   * will result in this:
   * ```swift
   * > req.get("accept")
   * "text/html, application/json
   * ```
   */
  @inlinable
  func header(_ headerName: String) -> String? {
    let values = headers[headerName]
    guard !values.isEmpty else { return nil }
    return headers[headerName].joined(separator: ", ")
  }
  
  /**
   * Aliased for ``header(_:)``.
   */
  @inlinable
  func get(_ headerName: String) -> String? {
    return header(headerName)
  }
}


// MARK: - Node API

public extension HTTPHeadersHolder {
  
  @inlinable
  func getHeader(_ name: String) -> Any? {
    let values = headers[name]
    guard !values.isEmpty else { return nil }
    if !shouldReturnArrayValueForHeader(name) && values.count == 1 {
      return values.first
    }
    return values
  }
  
  @usableFromInline
  internal func shouldReturnArrayValueForHeader(_ name: String) -> Bool {
    // TODO: which headers only make sense as arrays? Accept?
    return false
  }
}

public extension HTTPMutableHeadersHolder {

  @inlinable
  func setHeader(_ name: String, _ value: String) {
    headers.replaceOrAdd(name: name, value: value)
  }
  @inlinable
  func setHeader<S: StringProtocol>(_ name: String, _ value: S) {
    setHeader(name, String(value))
  }
  @inlinable
  func setHeader(_ name: String, _ value: Int) {
    setHeader(name, String(value))
  }
  // TODO: Bool version for Brief
  
  @inlinable
  func setHeader<S: Collection>(_ name: String, _ value: S)
         where S.Element == String
  {
    headers.remove(name: name)
    value.forEach { headers.add(name: name, value: $0) }
  }
  @inlinable
  func setHeader<S: Collection>(_ name: String, _ value: S)
         where S.Element: StringProtocol
  {
    setHeader(name, value.map { String($0) })
  }
  
  @inlinable
  func setHeader(_ name: String, _ value: Any) {
    if let value = value as? String {
      setHeader(name, value)
    }
    else if let value = value as? [ String ] {
      setHeader(name, value)
    }
    else {
      setHeader(name, stringForValue(value, of: name))
    }
  }
  
  @inlinable
  func removeHeader(_ name: String) {
    headers.remove(name: name)
  }
  
  // MARK: - Support
  
  @usableFromInline
  internal func stringForValue(_ value: Any, of header: String) -> String {
    // TODO: improve, support HTTP dates, Ints, etc
    return "\(value)"
  }
}
