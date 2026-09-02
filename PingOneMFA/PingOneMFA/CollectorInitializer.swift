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

    @objc
    public static func registerCollectorsWithCompletion(_ completion: @escaping @convention(block) @Sendable () -> Void) {
        Task {
            await registerCollectorsAsync()
            completion()
        }
    }

    public static func registerCollectorsAsync() async {
        await CollectorFactory.shared.register(type: MobilePairingConstants.type) { json in
            MobilePairingCollector(with: json)
        }
    }
}
