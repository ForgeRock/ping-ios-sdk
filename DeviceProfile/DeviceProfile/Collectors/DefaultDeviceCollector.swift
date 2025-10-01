//
//  DefaultDeviceCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2019 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

// MARK: - DefaultDeviceCollector

/// Factory for creating the standard set of device information collectors.
///
/// This struct provides a convenient way to obtain the default collection
/// of device collectors that gather comprehensive device profile information
/// including platform, hardware, network, and capability data.
public struct DefaultDeviceCollector {
    
    /// Creates and returns the standard set of device collectors.
    ///
    /// This method provides a pre-configured array of collectors that gather
    /// essential device information for device profiling and fingerprinting purposes.
    ///
    /// - Returns: Array of device collectors for comprehensive data collection
    ///
    /// ## Included Collectors
    /// - **PlatformCollector**: OS version, device model, locale, security status
    /// - **HardwareCollector**: Memory, CPU, display, and camera specifications
    /// - **BrowserCollector**: User agent string from WebKit engine
    /// - **TelephonyCollector**: Cellular carrier and network information
    /// - **NetworkCollector**: Current network connectivity status
    /// - **BluetoothCollector**: Bluetooth Low Energy capability information
    ///
    /// ## Usage Example
    /// ```swift
    /// let collectors = DefaultDeviceCollector.defaultDeviceCollectors()
    /// let deviceProfile = try await collectors.collect()
    /// ```
    ///
    /// ## Customization
    /// You can modify the returned array to add, remove, or replace collectors:
    /// ```swift
    /// var collectors = DefaultDeviceCollector.defaultDeviceCollectors()
    /// collectors.append(CustomCollector())
    /// collectors.removeAll { $0.key == "bluetooth" }
    /// ```
    ///
    /// ## Performance Notes
    /// - Each collector operates independently and asynchronously
    /// - Failed collectors don't prevent others from succeeding
    /// - Collection order may vary due to async execution
    /// - Some collectors may require user permissions (location, camera)
    public static func defaultDeviceCollectors() -> [any DeviceCollector] {
        return [
            PlatformCollector(),
            HardwareCollector(),
            BrowserCollector(),
            TelephonyCollector(),
            NetworkCollector(),
            BluetoothCollector(),
        ]
    }
}
