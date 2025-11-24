// 
//  ContinueNode.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

extension ContinueNode {
    /// Returns the list of collectors from the actions.
    public var collectors: [any Collector] {
        return actions.compactMap { $0 as? (any Collector) }
    }
}
