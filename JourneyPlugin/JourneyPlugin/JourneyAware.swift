//
//  JourneyAware.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import PingOrchestrate

/// A protocol that defines a type for JourneyAware.
/// Exposes the journey property that can be set.
/// This protocol is used to inject the Journey instance into Callbacks that need it.
/// - Parameters:
///  - journey: The Journey instance that the Callback is aware of.
public protocol JourneyAware {
    var journey: Journey? { get set }
}
