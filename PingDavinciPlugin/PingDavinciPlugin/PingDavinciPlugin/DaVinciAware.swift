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

public typealias DaVinci = Workflow

/// A protocol that defines a type for DaVinciAware.
/// Exposes the davinci property that can be set.
/// This protocol is used to inject the DaVinci instance into Collectors that need it.
public protocol DaVinciAware {
    var davinci: DaVinci? { get set }
}
