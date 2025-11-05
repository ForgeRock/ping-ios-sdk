//
//  DeviceCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

// MARK: - DeviceCollector Protocol

/// Protocol for device collectors that gather specific types of device information.
///
/// Device collectors are responsible for collecting specific categories of device data
/// such as platform information, hardware specifications, network status, etc.
/// Each collector returns a specific data type and has a unique key identifier.
///
/// Example usage:
/// ```swift
/// let platformCollector = PlatformCollector()
/// let platformInfo = try await platformCollector.collect()
/// print("Collector key: \(platformCollector.key)")
/// ```
public protocol DeviceCollector {
    /// The type of data this collector returns
    associatedtype DataType: Codable

    /// Unique identifier for this collector type
    var key: String { get }
    
    /// Collects device information of the specified type
    /// - Returns: The collected data, or nil if collection fails
    /// - Throws: Any errors that occur during data collection
    func collect() async throws -> DataType?
}

// MARK: - Logger Protocol

/// Protocol for collectors that support logging functionality
protocol LoggerAware {
    /// Logger instance for recording collection events and errors
    var logger: Logger { get set }
}

// MARK: - Collection Extensions

/// Extension to collect data from multiple collectors and combine into a unified JSON structure
extension Array where Element == any DeviceCollector {
    
    /// Collects data from all collectors in the array and returns a unified result
    ///
    /// This method iterates through all collectors, attempts to collect their data,
    /// and combines the results into a single dictionary where keys are collector
    /// identifiers and values are the serialized JSON data.
    ///
    /// - Returns: Dictionary containing all successfully collected data
    /// - Throws: JSON encoding errors (collection errors are logged but don't stop execution)
    ///
    /// Example:
    /// ```swift
    /// let collectors: [any DeviceCollector] = [
    ///     PlatformCollector(),
    ///     HardwareCollector()
    /// ]
    /// let results = try await collectors.collect()
    /// // Results: ["platform": {...}, "hardware": {...}]
    /// ```
    func collect() async throws -> [String: Any] {
        var result: [String: Any] = [:]

        for collector in self {
            do {
                // Attempt to collect data from the collector
                if let data = try await collector.collect() {
                    // Encode the collected data to JSON
                    let jsonData = try JSONEncoder().encode(data)
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
                    result[collector.key] = jsonObject
                }
            } catch {
                // Log encoding/collection errors but continue with other collectors
                if let loggerAwareCollector = collector as? LoggerAware {
                    loggerAwareCollector.logger.e("Error collecting data from \(collector.key): \(error.localizedDescription)", error: error)
                }
            }
        }

        return result
    }
}
