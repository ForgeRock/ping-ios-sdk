//
//  JourneyPlugin.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

/// A typealias mapping Journey to the underlying Workflow type used by the orchestrator.
/// This provides a convenient name where Journey is exposed to SDK users.
public typealias Journey = Workflow

/// Configuration for Journey workflows.
///
/// Conforms to `WorkflowConfig` and `Sendable`, and holds parameters required
/// to communicate with the Journey backend.
/// - Important: Provide `serverUrl` and `realm` appropriate to your deployment.
public class JourneyConfig: WorkflowConfig, @unchecked Sendable {
    /// The base URL of the server handling Journey requests, for example:
    /// https://example.am.com/am
    public var serverUrl: String?
    
    /// The realm used for authentication and callback endpoints.
    /// Defaults to the value in `JourneyConstants.realm`.
    public var realm: String = JourneyConstants.realm
    
    /// The cookie name used by the Journey backend.
    /// Defaults to `JourneyConstants.cookie`.
    public var cookie: String = JourneyConstants.cookie
}

