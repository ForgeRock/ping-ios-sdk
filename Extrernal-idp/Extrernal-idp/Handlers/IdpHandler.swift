//
//  IdpHandler.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Logger protocol that provides methods for logging different levels of information.
public protocol IdpHandler {
    var tokenType: String { get set }
    
    func authorize(url: URL?) async throws -> Request
}
