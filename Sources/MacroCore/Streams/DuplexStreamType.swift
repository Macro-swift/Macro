//
//  DuplexStreamType.swift
//  Macro
//
//  Created by Helge Hess.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

public protocol DuplexStreamType: ReadableStreamType,
                                  WritableStreamType
{
}

public protocol DuplexByteStreamType: ReadableByteStreamType,
                                      WritableByteStreamType
{
}
