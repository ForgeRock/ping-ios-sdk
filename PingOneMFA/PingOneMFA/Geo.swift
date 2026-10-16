//
//  Geo.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Geographic region selector for the PingOneMFA SDK.
///
/// Specifies the PingOne cloud region to connect to. Maps 1:1 to `PingOneSDK.PingOneGeo`
/// without leaking the upstream module.
public enum Geo: Sendable, Equatable {
    /// The North America region.
    case northAmerica
    /// The Europe region.
    case europe
    /// The Australia region.
    case australia
    /// The Canada region.
    case canada
    /// The Singapore region.
    case singapore
}

