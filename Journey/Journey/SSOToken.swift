//
//  SSOToken.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate

/// Define the SSOToken protocol
protocol SSOToken: Session, Codable {
    var successUrl: String { get }
    var realm: String { get }
}

/// Define the SSOTokenImpl class
final class SSOTokenImpl: SSOToken, Sendable, Codable {
    let value: String
    let successUrl: String
    let realm: String

    init(value: String, successUrl: String, realm: String) {
        self.value = value
        self.successUrl = successUrl
        self.realm = realm
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case value
        case successUrl
        case realm
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.value = try container.decode(String.self, forKey: .value)
        self.successUrl = try container.decode(String.self, forKey: .successUrl)
        self.realm = try container.decode(String.self, forKey: .realm)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(successUrl, forKey: .successUrl)
        try container.encode(realm, forKey: .realm)
    }
}
