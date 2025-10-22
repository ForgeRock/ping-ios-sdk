//
//  DeviceRegistrationCollector.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation

/// Class representing a device registration collector.
/// Inherits from `FieldCollector` and is used to collect device information.
/// - property devices: The list of devices.
/// - property value: The selected device.
/// - method eventType: Returns the event type.
/// - method payload: Returns the selected device type.
/// - method init: Initializes a new instance of `DeviceRegistrationCollector`.
///
open class DeviceRegistrationCollector: FieldCollector<String>, Submittable, @unchecked Sendable {
    
    /// The list of devices.
    public private(set) var devices: [Device] = []
    /// The selected device.
    public var value: Device? = nil
    
    /// Initializes a new instance of `DeviceRegistrationCollector` with the given JSON input.
    public required init(with json: [String : Any]) {
        super.init(with: json)
        let devicesJson = json[Constants.options] as? [[String: Any]] ?? [[:]]
        if let jsonData = try? JSONSerialization.data(withJSONObject: devicesJson, options: []) {
            devices = Device.populateDevices(from: jsonData)
        }
    }
    
    /// Return event type
    public func eventType() -> String {
        return Constants.submit
    }
    
    /// Returns the selected device type.
    override open func payload() -> String? {
        return value?.type
    }
}
