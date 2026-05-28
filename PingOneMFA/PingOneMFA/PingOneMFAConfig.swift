//
//  PingOneMFAConfig.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Geographic region selector for the PingOneMFA SDK.
/// Maps 1:1 to `PingOneSDK.PingOneGeo` without leaking the upstream module.
public enum PingOneMFAGeo: Sendable, Equatable {
    case northAmerica
    case europe
    case australia
    case canada
    case singapore
}

