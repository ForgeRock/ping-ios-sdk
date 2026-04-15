// 
//  RequestInterceptor.swift
//  PingOrchestrate
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingNetwork

/// A protocol for callback/collector-level request interception.
///
/// Conforming types (e.g., `IdpCollector`) can modify the outgoing HTTP request
/// when a `ContinueNode` builds its submission request via `asRequest()`.
/// This is invoked per-callback/collector inside Journey's `JourneyContinueNode`
/// and DaVinci's `Connector`, allowing individual actions to inject headers,
/// parameters, or replace the request entirely based on their internal state.
///
/// For workflow-wide request customization, use modules like `CustomHeader` instead.
///
/// - Note: Not related to `HttpRequestInterceptor` in PingNetwork, which operates
///   at the HTTP client transport level via `HttpClientConfig.onRequest(_:)`.
public protocol RequestInterceptor {
    /// Intercepts the request before it is sent.
    /// - Parameters:
    ///   - context: The current flow context.
    ///   - request: The request to modify.
    /// - Returns: The original or modified request.
    func intercept(context: FlowContext, request: Request) -> Request
}
