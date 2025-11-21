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

public typealias Journey = Workflow

/// Define a configuration object
/// that conforms to `WorkflowConfig` and `Sendable`.
/// This configuration is used to set up the journey with various parameters such as server URL, realm, cookie, and authentication options.
///  - Parameters:
///  - serverUrl: The URL of the server.
///  - realm: The realm to use for the journey.
///  - cookie: The cookie name to use for the journey.
///  - forceAuth: A boolean indicating whether to force authentication.
///  - noSession: A boolean indicating whether to allow the journey to complete without generating a session.
public class JourneyConfig: WorkflowConfig, @unchecked Sendable {
    public var serverUrl: String?
    public var realm: String = JourneyConstants.realm
    public var cookie: String = JourneyConstants.cookie
}
