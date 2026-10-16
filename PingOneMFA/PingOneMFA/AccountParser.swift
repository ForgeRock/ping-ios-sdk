//
//  AccountParser.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

internal struct AccountParser {

    internal static func parse(_ deviceInfo: [String: Any]?) throws -> [PingOneMfaAccount] {
        guard let deviceInfo, !deviceInfo.isEmpty else { return [] }
        
        guard JSONSerialization.isValidJSONObject(deviceInfo) else {
            throw PingOneMFAError("Failed to serialize device info: contains a value that is not JSON-serializable")
        }

        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: deviceInfo)
        } catch {
            throw PingOneMFAError("Failed to serialize device info: \(error.localizedDescription)")
        }

        let decoded: [String: RegionDto]
        do {
            decoded = try JSONDecoder().decode([String: RegionDto].self, from: data)
        } catch {
            throw PingOneMFAError("Failed to decode device info: \(error.localizedDescription)")
        }

        return decoded.flatMap { region, regionDto in
            (regionDto.users ?? []).map { user in
                PingOneMfaAccount(
                    region: region,
                    id: user.id ?? "",
                    deviceId: user.device?.id ?? "",
                    environmentId: user.environment?.id ?? "",
                    name: user.name?.given ?? "",
                    family: user.name?.family ?? ""
                )
            }
        }
    }
}

private struct RegionDto: Decodable {
    var users: [UserDto]?
}

private struct UserDto: Decodable {
    var id: String?
    var environment: IdContainer?
    var device: IdContainer?
    var name: NameDto?
}

private struct IdContainer: Decodable {
    var id: String?
}

private struct NameDto: Decodable {
    var given: String?
    var family: String?
}
