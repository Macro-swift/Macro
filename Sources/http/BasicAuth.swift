//
//  BasicAuth.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public enum BasicAuthModule {}
public typealias basicAuth = BasicAuthModule

import Foundation
import enum MacroCore.CharsetConversionError

public extension BasicAuthModule {

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

  static func auth(_ req: IncomingMessage, encoding: String.Encoding = .utf8)
                throws -> Credentials
  {
    guard let authorization = req.getHeader("Authorization") else {
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
}
