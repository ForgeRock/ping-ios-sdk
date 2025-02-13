//
//  IdpRequestHandler.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Interface representing an Identity Provider (IdP) handler.

public protocol IdpRequestHandler {
    var tokenType: String { get set }
    
    func authorize(url: URL?) async throws -> Request
}

