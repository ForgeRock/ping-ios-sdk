//
//  MobilePairingClient.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

protocol MobilePairingClient: Sendable {
    func pair(pairingKey: String) async throws
}

struct PingOneMFAPairingClient: MobilePairingClient {
    func pair(pairingKey: String) async throws {
        try await PingOneMFA.pair(pairingKey: pairingKey)
    }
}
