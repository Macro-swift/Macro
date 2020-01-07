//
//  ResultExtensions.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

internal extension Result where Failure : Swift.Error {
  
  @inlinable
  var jsValue : Success? {
    switch self {
      case .success(let success) : return success
      case .failure              : return nil
    }
  }
  @inlinable
  var jsError : Swift.Error? {
    switch self {
      case .success            : return nil
      case .failure(let error) : return error
    }
  }

  @inlinable
  var jsTuple : ( Swift.Error?, Success? ) {
    switch self {
      case .success(let success) : return ( nil, success )
      case .failure(let error)   : return ( error, nil )
    }
  }
}
