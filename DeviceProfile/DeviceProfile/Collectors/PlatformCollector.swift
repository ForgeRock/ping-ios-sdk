//
//  PlatformCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import UIKit
import PingTamperDetector

// MARK: - PlatformCollector

/// Collector for device platform and system information.
///
/// This collector gathers comprehensive information about the iOS platform,
/// device model, system version, localization settings, and security status.
class PlatformCollector: DeviceCollector {
    typealias DataType = PlatformInfo
    
    /// Unique identifier for platform information data
    let key = "platform"
    
    /// Collects comprehensive platform information
    /// - Returns: PlatformInfo containing system and device details
    func collect() async -> PlatformInfo? {
        return await PlatformInfo()
    }
}

// MARK: - PlatformInfo

/// Comprehensive platform information about the iOS device and system.
///
/// This structure contains detailed information about the operating system,
/// device model, localization settings, and security characteristics.
struct PlatformInfo: Codable {
    /// Operating system name (e.g., "iOS", "iPadOS")
    let platform: String
    
    /// Operating system version (e.g., "17.0.1")
    let version: String
    
    /// Device category (e.g., "iPhone", "iPad")
    let device: String
    
    /// User-assigned device name (e.g., "John's iPhone")
    let deviceName: String
    
    /// Specific device model identifier (e.g., "iPhone15,2")
    /// - Note: This is the technical model identifier, not the marketing name
    let model: String
    
    /// Device manufacturer (always "Apple" for iOS devices)
    let brand: String
    
    /// Primary language code (e.g., "en", "es", "fr")
    /// - Note: May be nil if locale information is unavailable
    let locale: String?
    
    /// Time zone identifier (e.g., "America/New_York", "Europe/London")
    let timeZone: String
    
    /// Jailbreak detection score (0.0 = no jailbreak, 1.0 = likely jailbroken)
    let jailBreakScore: Double
    
    /// Initializes platform information by collecting system details
    init() async {
        self.platform = await UIDevice.current.systemName
        self.version = await UIDevice.current.systemVersion
        self.device = await UIDevice.current.model
        self.deviceName = await UIDevice.current.name
        self.model = Self.getDeviceModel()
        self.brand = "Apple"
        self.locale = Locale.current.languageCode
        self.timeZone = TimeZone.current.identifier
        
        self.jailBreakScore = await TamperDetector().analyze()
    }
    
    /// Retrieves the specific device model identifier using system info
    /// - Returns: Device model string (e.g., "iPhone15,2", "iPad13,1")
    ///
    /// ## Implementation Details
    /// - Uses the `uname` system call to get hardware information
    /// - Extracts the machine identifier from system info
    /// - Converts the C string to a Swift String
    ///
    /// ## Example Return Values
    /// - iPhone 14 Pro: "iPhone15,2"
    /// - iPad Pro 12.9" (6th gen): "iPad13,1"
    /// - iPhone 13 mini: "iPhone14,4"
    static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return convertSysInfo(mirror: Mirror(reflecting: systemInfo.machine))
    }
    
    /// Converts system info structure to readable string
    /// - Parameter mirror: Mirror reflection of the uname machine field
    /// - Returns: Converted string representation of the machine identifier
    ///
    /// ## Implementation Details
    /// - Uses Mirror reflection to iterate through the C array
    /// - Converts Int8 values to Unicode scalars
    /// - Stops at null terminator (0 value)
    /// - Builds the final string character by character
    static func convertSysInfo(mirror: Mirror) -> String {
        let result = mirror.children.reduce("") { accumulator, element in
            guard let value = element.value as? Int8, value != 0 else {
                return accumulator
            }
            return accumulator + String(UnicodeScalar(UInt8(value)))
        }
        return result
    }
}
