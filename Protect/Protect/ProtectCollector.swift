//
//  ProtectCollector.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.

import Foundation
import PingDavinci

/// A collector class for handling RISK Component.
/// This class implements the `AnyFieldCollector` and `Collector` protocols to collect data related to the Protect SDK.
///
/// - property key: The unique identifier for the collector.
/// - property behavioralDataCollection: A boolean indicating whether behavioral data collection is enabled.
/// - property universalDeviceIdentification: A boolean indicating whether universal device identification is enabled.
@objc
public class ProtectCollector: NSObject, AnyFieldCollector, Collector, @unchecked Sendable {
    
    private(set) var key: String = ""
    private(set) var behavioralDataCollection: Bool = true
    private(set) var universalDeviceIdentification: Bool = false
    
    private var value: String = ""
    
    /// Initializes the risk collector with the given input dictionary.
    ///
    /// - Parameter input: The dictionary containing initialization data.
    public required init(with json: [String : Any]) {
        key = json[Constants.key] as? String ?? ""
        behavioralDataCollection = json[Constants.behavioralDataCollection] as? Bool ?? true
        universalDeviceIdentification = json[Constants.universalDeviceIdentification] as? Bool ?? false
    }
    
    /// Initializes the `ProtectCollector` with the given value. The `ProtectCollector` does not hold any value.
    /// - Parameter input: The value to initialize the collector with.
    public func initialize(with value: Any) {}
    
    /// The UUID of the field collector.
    public var id: String {
        return key
    }
    
    public func payload() -> String? {
        return value.isEmpty ? nil : value
    }
    
    /// Type-erased version of payload()
    public func anyPayload() -> Any? {
        return payload()
    }
    
    /// Validates this collector, returning a list of validation errors if any.
    /// - Returns: An array of `ValidationError`.
    public func validate() -> [PingDavinci.ValidationError] {
        return []
    }
    
    /// Collects data from the Protect SDK and returns it as a Result.
    ///
    /// - Returns: Result containing the collected data or an error if an exception occurs.
    public func collect() async -> Result<String, Error> {
        do {
            // Configure Protect SDK
            await Protect.config { config in
                config.isBehavioralDataCollection = behavioralDataCollection
            }
            
            // Initialize the Protect SDK, if Protect is already initialized, this will be a no-op
            try await Protect.initialize()
            
            // If when Protect is initialized with behavioralDataCollection set to false, this will be a no-op
            if behavioralDataCollection {
                try await Protect.resumeBehavioralData()
            } else {
                try await Protect.pauseBehavioralData()
            }
            
            value =  try await Protect.data()
            return .success(value)
        } catch {
            return .failure(error)
        }
    }
}

extension ProtectCollector {
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCollector() {
        Task {
            await CollectorFactory.shared.register(type: Constants.PROTECT, collector: ProtectCollector.self)
        }
    }
}

extension Constants {
    public static let PROTECT = "PROTECT"
    public static let behavioralDataCollection = "behavioralDataCollection"
    public static let universalDeviceIdentification = "universalDeviceIdentification"
}
