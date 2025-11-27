//
//  DaVinciAware.swift
//  PingDavinciPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// A typealias mapping DaVinci to the underlying Workflow type used by the orchestrator.
/// This provides convenient naming where the DaVinci experience is exposed to SDK users.
public typealias DaVinci = Workflow

/// A protocol for types that need access to the DaVinci workflow instance.
/// Conforming types can receive the DaVinci instance to perform workflow-related actions
/// such as advancing the flow, accessing shared context, or building requests.
///
/// Typical conformers are collectors that must send follow-up requests
/// or need to read data from the current workflow context.
public protocol DaVinciAware {
    /// The active DaVinci workflow instance, if available.
    /// Implementers should set this when creating or injecting collectors that
    /// need to interact with the DaVinci workflow.
    var davinci: DaVinci? { get set }
}

