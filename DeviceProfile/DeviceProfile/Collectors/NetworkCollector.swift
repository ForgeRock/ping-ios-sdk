//
//  NetworkCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import Network

// MARK: - NetworkCollector

/// Collector for device network connectivity information.
///
/// This collector determines the current network connectivity status
/// using the modern Network framework available in iOS 13+.
/// It provides a snapshot of connectivity at collection time.
public class NetworkCollector: DeviceCollector, @unchecked Sendable {
    public typealias DataType = NetworkInfo
    
    /// Unique identifier for network connectivity data
    public let key = "network"
    
    /// Collects current network connectivity information
    /// - Returns: NetworkInfo containing connectivity status
    public func collect() async -> NetworkInfo? {
        return await NetworkInfo()
    }
    
    /// Initializes a new instance
    public init() {}
}

// MARK: - NetworkInfo

/// Information about the device's current network connectivity status.
///
/// This structure contains the basic connectivity state determined
/// at the time of collection using the Network framework.
public struct NetworkInfo: Codable, Sendable {
    /// Whether the device currently has network connectivity
    /// - Note: This represents the connectivity status at collection time
    let connected: Bool
    
    /// Initializes network information by checking current connectivity
    init() async {
        self.connected = await Self.isConnectedToNetwork()
    }
    
    /// Determines current network connectivity status
    /// - Returns: True if connected to any network, false otherwise
    ///
    /// ## Implementation Details
    /// - Uses NWPathMonitor from the Network framework
    /// - Provides an instantaneous connectivity check
    /// - Does not distinguish between network types (WiFi, cellular, etc.)
    ///
    /// ## Notes
    /// - This is a synchronous check of current status
    /// - For continuous monitoring, consider using NetworkPathMonitor directly
    /// - May not reflect rapid connectivity changes
    ///
    /// ## Connectivity States
    /// - `true`: Device has active network path
    /// - `false`: No network connectivity available
    private static func isConnectedToNetwork() async -> Bool {
        let monitor = NetworkPathMonitor()
        
        defer {
            monitor.stopMonitoring()
        }
        
        // Return current connectivity status
        return await withCheckedContinuation { continuation in
            monitor.statusUpdateCallback = { status in
                monitor.stopMonitoring()
                continuation.resume(returning: status == .satisfied)
            }
            monitor.startMonitoring()
        }
    }
}
