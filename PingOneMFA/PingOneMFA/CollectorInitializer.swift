//
//  CollectorInitializer.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import Foundation
import PingDavinciPlugin

@objc
public final class CollectorInitializer: NSObject {
    @objc
    public static func registerCollectors() {
        Task { await registerCollectorsAsync() }
    }

    static func registerCollectorsAsync() async {
        await CollectorFactory.shared.register(type: MobilePairingConstants.type) { json in
            MobilePairingCollector(with: json)
        }
    }
}
