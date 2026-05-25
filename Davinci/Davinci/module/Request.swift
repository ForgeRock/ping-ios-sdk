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
    
    /// Populates a request to verify a user code in the Device Authorization Grant flow (RFC 8628).
    ///
    /// Constructs the device-flow verification URL from
    /// `OpenIdConfiguration.deviceAuthorizationEndpoint` by stripping the trailing
    /// `/as/device_authorization` segment to obtain the tenant-scoped base URL, then appending
    /// `/applications/{clientId}/deviceFlow`. The user code is sent as a `userCode` query parameter
    /// (PingOne format).
    ///
    /// **Example**
    /// - Endpoint: `https://auth.pingone.ca/{tenantId}/as/device_authorization`
    /// - Result:   `https://auth.pingone.ca/{tenantId}/applications/{clientId}/deviceFlow?userCode={userCode}`
    ///
    /// - Parameters:
    ///   - request: The request to populate.
    ///   - userCode: The user code obtained from the device authorization response that needs to be verified.
    /// - Returns: The populated `Request` ready for execution.
    internal func populateDeviceFlowVerificationRequest(
        request: Request,
        userCode: String
    ) -> Request {
        let deviceAuthEndpoint = openId?.deviceAuthorizationEndpoint ?? ""

        // Strip "/as/device_authorization" to obtain the tenant-scoped base URL.
        let baseUrl: String
        if deviceAuthEndpoint.hasSuffix(Constants.asDeviceAuthorizationPath) {
            baseUrl = String(deviceAuthEndpoint.dropLast(Constants.asDeviceAuthorizationPath.count))
        } else {
            baseUrl = deviceAuthEndpoint
        }

        request.url = "\(baseUrl)/applications/\(clientId)/deviceFlow"
        request.setParameter(name: Constants.userCodeCamel, value: userCode)

        return request
    }

    private enum Constants {
        static let asDeviceAuthorizationPath = "/as/device_authorization"
        static let userCodeCamel = "userCode"
    }
}

