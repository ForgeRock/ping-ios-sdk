//
//  IdpResult.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

public struct IdpResult {
    public let token: String
    public let additionalParameters: [String: String]?
    
    public init(token: String, additionalParameters: [String : String]?) {
        self.token = token
        self.additionalParameters = additionalParameters
    }
}
