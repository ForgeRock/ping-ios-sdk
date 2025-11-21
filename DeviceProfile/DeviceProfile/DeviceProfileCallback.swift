//
//  DeviceProfileCallback.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourneyPlugin
import PingDeviceId
import PingLogger

// MARK: - DeviceProfileCallback

/// A callback implementation for collecting and processing device profile information.
///
/// This callback is used within the Ping Identity journey framework to gather device metadata
/// and location information based on server configuration. It extends AbstractCallback for
/// modern Swift callback handling and provides a streamlined interface for device profiling.
///
/// ## Usage in Journey Flow
/// 1. Server configures what data to collect (metadata, location)
/// 2. Callback receives configuration via `initValue` calls
/// 3. Client calls `collect()` with optional customization
/// 4. Device profile data is submitted back to server
///
/// ## Privacy Considerations
/// - Location collection requires user permission
/// - Metadata collection is configurable per server policy
/// - All data collection respects system privacy settings
public class DeviceProfileCallback: AbstractCallback, ObservableObject, @unchecked Sendable {
    
    // MARK: - Configuration Properties
    
    /// Indicates whether metadata collection is enabled for this callback.
    /// This value is set during initialization based on server configuration.
    ///
    /// When enabled, the callback will collect comprehensive device information
    /// including platform details, hardware specs, network status, etc.
    private(set) public var metadata: Bool = false
    
    /// Indicates whether location collection is enabled for this callback.
    /// This value is set during initialization based on server configuration.
    ///
    /// When enabled, the callback will attempt to collect device location
    /// coordinates, subject to user permissions and privacy settings.
    private(set) public var location: Bool = false
    
    /// A message from the server, typically containing instructions or information
    /// about the device profile collection process.
    ///
    /// This message can provide context about why device profiling is being
    /// requested or instructions for the user about the collection process.
    private(set) public var message: String = ""
    
    // MARK: - Initialization
    
    /// Initializes callback properties based on server-provided configuration.
    ///
    /// This method is called automatically during callback initialization to set up
    /// the callback based on the server's requirements for device profiling.
    ///
    /// - Parameters:
    ///   - name: The name of the property being initialized
    ///   - value: The value containing the property configuration
    ///
    /// ## Supported Properties
    /// - `metadata`: Boolean indicating whether to collect device metadata
    /// - `location`: Boolean indicating whether to collect location information
    /// - `message`: String containing server instructions or context
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.metadata:
            if let boolValue = value as? Bool {
                self.metadata = boolValue
            }
        case JourneyConstants.location:
            if let boolValue = value as? Bool {
                self.location = boolValue
            }
        case JourneyConstants.message:
            if let stringValue = value as? String {
                self.message = stringValue
            }
        default:
            // Unknown property names are ignored
            break
        }
    }
    
    // MARK: - Collection Methods
    
    /// Collects device profile information and submits it to the server.
    ///
    /// This method orchestrates the complete device profile collection process,
    /// allowing for custom configuration of collectors and handling all aspects
    /// of data gathering and submission.
    ///
    /// - Parameter configBlock: Configuration block for customizing device profile collection
    /// - Returns: Result containing the collected device profile or an error
    ///
    /// ## Collection Process
    /// 1. Creates DeviceProfileConfig with server settings
    /// 2. Applies custom configuration via configBlock
    /// 3. Performs device profile collection
    /// 4. Serializes results to JSON
    /// 5. Submits data to server via input() call
    ///
    /// ## Configuration Example
    /// ```swift
    /// let result = await callback.collect { config in
    ///     config.collectors {
    ///         return [
    ///             PlatformCollector(),
    ///             CustomCollector()
    ///         ]
    ///     }
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Returns .failure for collection or encoding errors
    /// - Returns .success with collected data dictionary
    /// - Automatically submits successful results to server
    public func collect(
        configBlock: @escaping @Sendable (DeviceProfileConfig) -> Void = {_ in }
    ) async -> Result<[String: any Sendable], Error> {
        
        // Create configuration with server settings
        let config = DeviceProfileConfig()
        config.metadata = metadata
        config.location = location
        
        // Apply custom configuration
        configBlock(config)
        
        do {
            // Perform device profile collection
            let collector = DeviceProfileCollector(config: config)
            guard let deviceProfile = try await collector.collect() else {
                throw DeviceProfileError.collectionFailed
            }
            
            // Encode results to JSON
            let jsonData = try JSONEncoder().encode(deviceProfile)
            guard let profileDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                throw DeviceProfileError.serializationFailed
            }
            
            // Submit to server
            let jsonString = DeviceProfileUtils.jsonStringify(value: profileDict as AnyObject)
            _ = input(jsonString)
            
            // JSON serialization produces only Sendable types (String, Number, Bool, Array, Dictionary)
            // Use unsafeBitCast to convert [String: Any] to [String: any Sendable]
            let sendableDict = unsafeBitCast(profileDict, to: [String: any Sendable].self)
            return .success(sendableDict)
            
        } catch {
            return .failure(error)
        }
    }
    
    /// Returns the payload for the callback submission.
    /// - Returns: JSON dictionary for server submission
    public override func payload() -> [String: Any] {
        return json
    }
}

// MARK: - DeviceProfileConfig

/// Configuration object for customizing device profile collection.
///
/// This class allows fine-grained control over what data is collected
/// and how the collection process behaves. It provides defaults that
/// can be overridden based on application needs.
public final class DeviceProfileConfig: @unchecked Sendable {
    /// Whether to collect device metadata (platform, hardware, etc.)
    public var metadata: Bool = false
    
    /// Whether to collect device location information
    public var location: Bool = false
    
    /// Logger instance for recording collection events
    public var logger: Logger = LogManager.warning
    
    /// Device identifier generator for unique device identification.
    /// Default value is `DefaultDeviceIdentifier()`
    public var deviceIdentifier: DeviceIdentifier? = try? DefaultDeviceIdentifier()
    
    /// Array of collectors to use for metadata gathering.
    /// Defaults valuse is `DefaultDeviceCollector.defaultDeviceCollectors()`
    public var collectors: [any DeviceCollector] =  DefaultDeviceCollector.defaultDeviceCollectors()
    
    /// Configures the collectors array using a builder pattern
    /// - Parameter configBlock: Block that returns the desired collectors array
    ///
    /// ## Usage Example
    /// ```swift
    /// config.collectors {
    ///     return [
    ///         PlatformCollector(),
    ///         HardwareCollector(),
    ///         CustomCollector()
    ///     ]
    /// }
    /// ```
    public func collectors(_ configBlock: () -> [any DeviceCollector]) {
        collectors = configBlock()
    }
    
    /// Initializes a new instance of `DeviceProfileConfig`
    public init() {}
}

// MARK: - Error Types

/// Errors that can occur during device profile collection
public enum DeviceProfileError: Error, LocalizedError {
    case collectionFailed
    case serializationFailed
    
    // String Description of the error
    public var errorDescription: String? {
        switch self {
        case .collectionFailed:
            return "Device profile collection failed"
        case .serializationFailed:
            return "Failed to serialize device profile data"
        }
    }
}

// MARK: - Constants Extension

extension JourneyConstants {
    /// Key for metadata configuration property
    static let metadata = "metadata"
}

