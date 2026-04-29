//
//  Request.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOidc
import PingOrchestrate
import PingNetwork

extension OidcClientConfig {
    /// Populates a DaVinci authorization request, handling both standard and
    /// PAR (RFC 9126) flows. Delegates to the shared async `populateRequest`
    /// in `PingOidc` with the DaVinci-specific `pi.flow` response mode.
    internal func populateRequest(
        request: Request,
        pkce: Pkce
    ) async throws -> Request {
        return try await populateRequest(request: request, pkce: pkce, responseMode: OidcClient.Constants.piflow)
    }
}

