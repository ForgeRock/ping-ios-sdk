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
import PingDavinciPlugin
import PingOrchestrate

/// A collector for device registration information.
///
/// This class is responsible for collecting information about device registration,
/// including the available devices and the user's selection.
open class DeviceRegistrationCollector: FieldCollector<String>, Submittable, Closeable, @unchecked Sendable {
    
    /// The list of available registration devices.
    public private(set) var devices: [Device] = []
    /// The device selected by the user for registration.
    public var value: Device? = nil
    
    /// Initializes a new instance of `DeviceRegistrationCollector` with the given JSON input.
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
    /// - Returns: The type of the selected device, or `nil` if no device is selected.
    override open func payload() -> String? {
        return value?.type
    }
    
    /// Resets the collector's state by clearing the selected device.
    public func close() {
        self.value = nil
    }
}
