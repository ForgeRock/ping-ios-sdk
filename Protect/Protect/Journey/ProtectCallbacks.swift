//
//  ProtectCallbacks.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingJourney
import Foundation

@objc
class ProtectCallbacks: NSObject {
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCallbacks() {
        CallbackRegistry.shared.register(type: JourneyConstants.pingOneProtectInitializeCallback, callback: PingOneProtectInitializeCallback.self)
        CallbackRegistry.shared.register(type: JourneyConstants.pingOneProtectEvaluationCallback, callback: PingOneProtectEvaluationCallback.self)
    }
}

extension JourneyConstants {
    public static let pingOneProtectInitializeCallback = "PingOneProtectInitializeCallback"
    public static let pingOneProtectEvaluationCallback = "PingOneProtectEvaluationCallback"
}
