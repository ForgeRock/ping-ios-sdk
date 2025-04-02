// 
//  Device.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// Struct representing a device.
/// - property id: The ID of the device.
/// - property type: The type of the device.
/// - property title: The title of the device.
/// - property description: The description of the device.
/// - property iconSrc: The icon source of the device.
/// - property isDefault: The default value of the device.
/// - property value: The value of the device.
/// - method populateDevices: Populates a list of devices from the JSON data.
///
public struct Device: Codable, @unchecked Sendable {
    var id: String?
    var type: String
    var title: String
    var description: String
    var iconSrc: URL
    var isDefault: Bool = false
    var value: String?
    
    /// Enum representing the coding keys.
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case description
        case iconSrc
        case isDefault = "default"
        case value
    }
    
    static func populateDevices(from jsonData: Data) -> [Device] {
        let decoder = JSONDecoder()
        do {
            let devices = try decoder.decode([Device].self, from: jsonData)
            return devices
        } catch {
            print("Error decoding devices: \(error)")
            return []
        }
    }
}
