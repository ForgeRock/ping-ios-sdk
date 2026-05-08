//
//  ProtectCallbacks.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

#if canImport(PingOneSignals)
import PingJourneyPlugin
import Foundation

@objc
class ProtectCallbacks: NSObject {
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCallbacks() {
        Task {
            await CallbackRegistry.shared.register(type: JourneyConstants.pingOneProtectInitializeCallback, callback: PingOneProtectInitializeCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.pingOneProtectEvaluationCallback, callback: PingOneProtectEvaluationCallback.self)
        }
    }
}

extension JourneyConstants {
    public static let pingOneProtectInitializeCallback = "PingOneProtectInitializeCallback"
    public static let pingOneProtectEvaluationCallback = "PingOneProtectEvaluationCallback"
}
#endif
