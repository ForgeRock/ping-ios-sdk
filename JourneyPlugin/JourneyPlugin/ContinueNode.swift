//
//  ContinueNode.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

extension ContinueNode {
    /// Returns the list of callbacks from this node's actions.
    public var callbacks: [any Callback] {
        return actions.compactMap { $0 as? (any Callback) }
    }
}
