// 
//  ContinueNodeAware.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate

/// An interface that should be implemented by classes that need to be aware of the ContinueNode.
/// The continueNode will be injected to the classes that implement this interface.
protocol ContinueNodeAware {
    var continueNode: ContinueNode? { get set }
}
