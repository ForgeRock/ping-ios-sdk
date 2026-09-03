//
//  CollectorInitializer.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinciPlugin

@objc
public final class CollectorInitializer: NSObject {
    @objc
    public static func registerCollectors() {
        Task { await registerCollectorsAsync() }
    }

    public static func registerCollectorsAsync() async {
        await CollectorFactory.shared.register(type: MobilePairingConstants.type) { json in
            MobilePairingCollector(with: json)
        }
    }
}
