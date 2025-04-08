// 
//  DeviceAuthenticationCollector.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//
import Foundation

open class DeviceAuthenticationCollector: FieldCollector<[String: Any]>, Submittable, @unchecked Sendable {
    /// The list of devices.
    public private(set) var devices: [Device] = []
    /// The selected device.
    public var value: Device? = nil
    
    /// Initializes a new instance of `DeviceRegistrationCollector`.
    public required init(with json: [String : Any]) {
        super.init(with: json)
        let devicesJson = json[Constants.devices] as? [[String: Any]] ?? [[:]]
        if let jsonData = try? JSONSerialization.data(withJSONObject: devicesJson, options: []) {
            devices = Device.populateDevices(from: jsonData)
        }
    }
    
    /// Return event type
    func eventType() -> String {
        return Constants.submit
    }
    
    /// Returns the selected device type.
    override open func payload() -> [String: Any]? {
        var deviceDictionary = [:] as [String: Any]
        deviceDictionary[Constants.type] = value?.type
        deviceDictionary[Constants.id] = value?.id
        deviceDictionary[Constants.value] = value?.value
        return deviceDictionary
    }
}
