//
//  DeviceProfileCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

// MARK: - DeviceProfileCollector

/// Main collector that orchestrates comprehensive device profile collection.
///
/// This collector serves as the root coordinator for gathering all device profile
/// information based on a specified configuration. It manages the collection process,
/// handles conditional data gathering, and combines results into a unified profile.
public class DeviceProfileCollector: DeviceCollector {
    
    public typealias DataType = DeviceProfileResult
    
    /// Configuration defining what data to collect and how to collect it
    private let config: DeviceProfileConfig
    
    /// The key identifier for this collector (empty string as this is the root collector)
    public let key: String = ""
    
    /// Initializes the device profile collector with the specified configuration
    /// - Parameter config: The configuration specifying what data to collect
    public init(config: DeviceProfileConfig) {
        self.config = config
    }
    
    /// Collects comprehensive device profile data based on the configuration.
    ///
    /// This method orchestrates the entire device profile collection process:
    /// 1. Configures loggers for all collectors that support logging
    /// 2. Retrieves the unique device identifier
    /// 3. Conditionally collects metadata if enabled in configuration
    /// 4. Conditionally collects location if enabled in configuration
    ///
    /// - Returns: A `DeviceProfileResult` containing the collected device profile data
    /// - Throws: Any errors that occur during the collection process
    ///
    /// ## Collection Process
    /// 1. **Logger Configuration**: Sets up logging for all collectors that support it
    /// 2. **Identifier Collection**: Retrieves unique device identifier
    /// 3. **Metadata Collection**: Gathers device specifications (if enabled)
    /// 4. **Location Collection**: Obtains geographic coordinates (if enabled)
    /// 5. **Result Assembly**: Combines all data into unified result structure
    ///
    /// ## Configuration Respect
    /// - Only collects metadata if `config.metadata` is true
    /// - Only collects location if `config.location` is true
    /// - Uses configured device identifier or falls back to empty string
    /// - Applies configured logger to all supporting collectors
    ///
    /// ## Error Handling
    /// - Propagates identifier collection errors
    /// - Handles metadata collection failures gracefully
    /// - Treats location collection failures as non-fatal
    public func collect() async throws -> DeviceProfileResult? {
        // Configure loggers for all collectors that support logging
        configureCollectorLoggers()
        
        // Collect unique device identifier
        let identifier = try await collectDeviceIdentifier()
        
        // Conditionally collect metadata based on configuration
        let metadata: [String: Any]? = config.metadata ?
            try await collectMetadata() : nil
        
        // Conditionally collect location based on configuration
        let location: LocationInfo? = config.location ?
            await collectLocation() : nil
        
        return DeviceProfileResult(
            identifier: identifier,
            metadata: metadata,
            location: location
        )
    }
    
    /// Configures logging for all collectors that support it
    private func configureCollectorLoggers() {
        for collector in config.collectors {
            if var loggerAware = collector as? LoggerAware {
                loggerAware.logger = config.logger
            }
        }
    }
    
    /// Collects the unique device identifier
    /// - Returns: Device identifier string, empty if none configured
    /// - Throws: Any errors from device identifier collection
    private func collectDeviceIdentifier() async throws -> String {
        return try await config.deviceIdentifier?.id ?? ""
    }
    
    /// Collects metadata from all configured collectors
    /// - Returns: Dictionary of collected metadata, or nil if collection fails
    /// - Throws: Collection or encoding errors
    private func collectMetadata() async throws -> [String: Any]? {
        return try await config.collectors.collect()
    }
    
    /// Collects location information if available
    /// - Returns: LocationInfo if successful, nil if unavailable or unauthorized
    @MainActor
    private func collectLocation() async -> LocationInfo? {
        return await LocationCollector().collect()
    }
}

// MARK: - DeviceProfileResult

/// Result structure containing all collected device profile information.
///
/// This structure represents the complete device profile, including the unique
/// identifier, device metadata, and geographic location if available.
public struct DeviceProfileResult: Codable, Sendable {
    /// Unique device identifier string
    let identifier: String
    
    /// Device metadata organized by collector type
    /// - Note: Uses AnyValue wrapper to handle heterogeneous data types
    let metadata: [String: AnyValue]?
    
    /// Device location coordinates if available and permitted
    let location: LocationInfo?
    
    /// Initializes a device profile result with collected data
    /// - Parameters:
    ///   - identifier: Unique device identifier
    ///   - metadata: Optional metadata dictionary from collectors
    ///   - location: Optional location information
    init(identifier: String, metadata: [String: Any]? = nil, location: LocationInfo? = nil) {
        self.identifier = identifier
        self.metadata = metadata?.mapValues(AnyValue.init)
        self.location = location
    }
    
    /// Convenience property to get metadata as [String: Any]
    /// - Returns: Metadata dictionary with unwrapped values, or nil if no metadata
    var metadataDict: [String: Any]? {
        return metadata?.mapValues(\.value)
    }
}

