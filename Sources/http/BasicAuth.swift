//
//  BasicAuth.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

public enum BasicAuthModule {}
public typealias basicAuth = BasicAuthModule

#if canImport(Foundation)
import Foundation
#endif
import enum MacroCore.CharsetConversionError

public extension BasicAuthModule {

  /**
   * HTTP Basic Authentication credentials as extracted by the
   * ``auth(_:encoding:)`` function, i.e. the name/password associated
   * with an ``IncomingMessage``.
   */
  struct Credentials {
    public let name : String
    public let pass : String
  }

  enum BasicAuthError : Swift.Error {
    case missingAuthorizationHeader
    case unexpectedAuthorizationHeaderType
    case invalidAuthorizationHeader
    case differentAuthorization
    case invalidBasicAuthorizationHeader
    case stringEncodingError
  }

  #if canImport(Foundation) // `String.Encoding.utf8`, provide alternative!
  /**
   * Extract HTTP Basic authentication credentials (name/pass) from the given
   * ```IncomingMessage```.
   *
   * - Parameters:
   *   - request:  The ``IncomingMessage`` containing the `Authorization`
   *               header.
   *   - encoding: The encoding the String is using.
   * - Returns: The ``Credentials``, i.e. `name`/`pass`.
   * - Throws:
   *   - ``BasicAuthError/missingAuthorizationHeader``: If there is no
   *     `Authorization` header
   *   - ``BasicAuthError/unexpectedAuthorizationHeaderType``: If the header
   *     existed, but wasn't a `String`.
   *   - ``BasicAuthError/invalidAuthorizationHeader``: If the header value
   *     syntax could not be parsed.
   *   - ``BasicAuthError/differentAuthorization``: If the header was set, but
   *     wasn't HTTP Basic authentication.
   *   - ``BasicAuthError/invalidBasicAuthorizationHeader``: If the header was
   *     set, but didn't had the right Basic auth syntax.
   *   - ``BasicAuthError/invalidBasicAuthorizationHeader``: If the header could
   *     be parsed, but the values could not be parsed using the given
   *     `encoding` specified.
   *
   */
  static func auth(_ request: IncomingMessage,
                   encoding: String.Encoding = .utf8)
                throws -> Credentials
  {
    guard let authorization = request.getHeader("Authorization") else {
      throw BasicAuthError.missingAuthorizationHeader
    }
    guard let authString = authorization as? String else {
      throw BasicAuthError.unexpectedAuthorizationHeaderType
    }
    
    guard let idx = authString
                      .firstIndex(where: { $0 == "\t" || $0 == " "}) else
    {
      throw BasicAuthError.invalidAuthorizationHeader
    }
    
    let scheme = authString[authString.startIndex..<idx].lowercased()
    guard scheme == "basic" else {
      throw BasicAuthError.differentAuthorization
    }
    
    let payload = String(authString[authString.index(after: idx)])
          .trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard let data = Data(base64Encoded: payload) else {
      throw BasicAuthError.invalidBasicAuthorizationHeader
    }
    
    guard let string = String(data: data, encoding: encoding) else {
      throw BasicAuthError.stringEncodingError
    }
    
    guard let colIdx = string.firstIndex(of: ":") else {
      throw BasicAuthError.invalidBasicAuthorizationHeader
    }
    
    return Credentials(
      name: String(string[string.startIndex..<colIdx]),
      pass: String(string[colIdx..<string.endIndex])
    )
  }
  #endif // canImport(Foundation)
}
