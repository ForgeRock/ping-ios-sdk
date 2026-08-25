//
//  MobilePairingClient.swift
//  PingOneMFA
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
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
