//
//  CollectorInitializer.swift
//  Fido2
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingDavinci

public class CollectorInitializer: NSObject {
    @objc public static func registerCollectors() {
        Task {
            await CollectorFactory.shared.register(type: "FIDO2", closure: { json in
                return try? AbstractFido2Collector.getCollector(with: json)
            })
        }
    }
}
