//
//  HardwareCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import UIKit
import AVFoundation

// MARK: - HardwareCollector

/// Collector for device hardware specifications and capabilities.
///
/// This collector gathers comprehensive hardware information including
/// manufacturer, memory specifications, CPU details, display properties,
/// and camera capabilities.
public class HardwareCollector: DeviceCollector {
    public typealias DataType = HardwareInfo
    
    /// Unique identifier for hardware information data
    public let key = "hardware"
    
    /// Collects comprehensive hardware information
    /// - Returns: HardwareInfo containing device specifications
    public func collect() async -> HardwareInfo? {
        return HardwareInfo()
    }
    
    /// Initializes a new instance
    public init() {}
}

// MARK: - HardwareInfo

/// Comprehensive hardware information about the device.
///
/// This structure contains detailed specifications about the device's
/// physical capabilities and hardware components.
public struct HardwareInfo: Codable {
    /// Device manufacturer (always "Apple" for iOS devices)
    let manufacturer: String
    
    /// Physical memory in megabytes (MB)
    /// - Note: This represents total RAM, not available memory
    let memory: Int64
    
    /// Number of CPU cores/processors available
    let cpu: Int
    
    /// Display specifications including dimensions and orientation
    /// - Note: Contains width, height, and orientation status
    let display: [String: Int]?
    
    /// Camera information including total number of cameras
    /// - Note: Includes front, back, and specialty cameras if available
    let camera: [String: Int]?
    
    /// Initializes hardware information by collecting device specifications
    init() {
        self.manufacturer = "Apple"
        self.memory = Self.getMemoryInfo()
        self.cpu = ProcessInfo.processInfo.processorCount
        self.display = Self.getDisplayInfo()
        self.camera = Self.getCameraInfo()
    }
    
    /// Retrieves total physical memory information
    /// - Returns: Physical memory in megabytes (MB)
    /// - Note: Converts from bytes to MB for easier interpretation
    private static func getMemoryInfo() -> Int64 {
        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let totalMemoryMB = Int64(totalMemoryBytes / (1024 * 1024))
        return totalMemoryMB
    }
    
    /// Retrieves display specifications and current orientation
    /// - Returns: Dictionary containing width, height, and orientation
    ///
    /// ## Return Values
    /// - `width`: Screen width in points
    /// - `height`: Screen height in points
    /// - `orientation`: 1 for portrait, 0 for landscape
    ///
    /// ## Notes
    /// - Values are in UIKit points, not pixels
    /// - Orientation is determined at collection time
    /// - Values represent logical screen dimensions
    private static func getDisplayInfo() -> [String: Int] {
        let screenBounds = UIScreen.main.bounds
        let isPortrait = UIDevice.current.orientation.isPortrait
        
        return [
            "width": Int(screenBounds.width),
            "height": Int(screenBounds.height),
            "orientation": isPortrait ? 1 : 0
        ]
    }
    
    /// Retrieves camera system information
    /// - Returns: Dictionary containing camera count information
    ///
    /// ## Implementation Details
    /// - Uses AVFoundation to discover available camera devices
    /// - Includes telephoto, dual-camera, and wide-angle cameras
    /// - Counts both front and back-facing cameras
    ///
    /// ## Return Values
    /// - `numberOfCameras`: Total count of available camera devices
    ///
    /// ## Notes
    /// - Requires camera access to be meaningful
    /// - May return 0 if camera access is restricted
    /// - Includes specialty cameras (telephoto, ultra-wide, etc.)
    private static func getCameraInfo() -> [String: Int] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTelephotoCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        let cameraCount = discoverySession.devices.count
        return ["numberOfCameras": cameraCount]
    }
}
