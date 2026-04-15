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
import PingDavinciPlugin
import PingOrchestrate

/// A collector for device authentication information.
///
/// This class is responsible for collecting information about device authentication,
/// including the available devices and the user's selection.
open class DeviceAuthenticationCollector: FieldCollector<[String: Any]>, Submittable, Closeable, @unchecked Sendable {
    /// The list of available authentication devices.
    public private(set) var devices: [Device] = []
    /// The device selected by the user for authentication.
    public var value: Device? = nil
    
    /// Initializes a new instance of `DeviceAuthenticationCollector` with the given JSON input.
    /// - Parameter json: A dictionary containing the collector's configuration.
    public required init(with json: [String : Any]) {
        super.init(with: json)
        let devicesJson = json[Constants.options] as? [[String: Any]] ?? [[:]]
        if let jsonData = try? JSONSerialization.data(withJSONObject: devicesJson, options: []) {
            devices = Device.populateDevices(from: jsonData)
        }
    }
    
    /// Returns the event type for this collector.
    /// - Returns: A string representing the event type, which is "submit".
    public func eventType() -> String {
        return Constants.submit
    }
    
    /// Constructs the payload to be sent to the server.
    /// - Returns: A dictionary containing the selected device's information, or `nil` if no device is selected.
    override open func payload() -> [String: Any]? {
        guard let value = value else {
            return nil
        }
        var deviceDictionary: [String: Any] = [:]
        deviceDictionary[Constants.type] = value.type
        deviceDictionary[Constants.id] = value.id
        deviceDictionary[Constants.description] = value.description
        return deviceDictionary
    }
    
    /// Resets the collector's state by clearing the selected device.
    public func close() {
        self.value = nil
    }
}
