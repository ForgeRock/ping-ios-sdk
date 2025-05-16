//
//  IdpResult.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Data class representing the result of an IDP authorization.
/// - Parameter token: The token returned by the IDP.
/// - Parameter additionalParameters: The additionalParameters.
public struct IdpResult: Sendable {
    public let token: String
    public let additionalParameters: [String: String]?
    
    /// Initializes a new instance of `IdpResult`.
    /// - Parameters:
    ///     - token: The token returned by the IDP.
    ///     - additionalParameters: The additional parameters.
    public init(token: String, additionalParameters: [String : String]?) {
        self.token = token
        self.additionalParameters = additionalParameters
    }
}
