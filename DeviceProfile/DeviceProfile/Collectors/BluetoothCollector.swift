// 
//  BluetoothCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CoreBluetooth

// MARK: - BluetoothCollector

/// Collector for Bluetooth Low Energy (BLE) capability information.
///
/// This collector determines whether the device supports Bluetooth Low Energy
/// by checking the CoreBluetooth framework's central manager state.
/// It provides information about BLE support without requiring location permissions.
class BluetoothCollector: DeviceCollector {
    typealias DataType = BluetoothInfo
    
    /// Unique identifier for bluetooth capability data
    let key = "bluetooth"
    
    /// Collects Bluetooth capability information
    /// - Returns: BluetoothInfo containing support status
    func collect() async -> BluetoothInfo? {
        return await BluetoothInfo()
    }
}

// MARK: - BluetoothInfo

/// Information about device Bluetooth Low Energy capabilities.
///
/// This structure contains the results of Bluetooth capability detection,
/// indicating whether the device supports BLE functionality.
struct BluetoothInfo: Codable {
    /// Whether the device supports Bluetooth Low Energy
    /// - Note: This indicates hardware support, not current power state or permissions
    let supported: Bool
    
    /// Initializes Bluetooth information by detecting BLE support
    init() async {
        supported = await Self.getBluetoothStatus()
    }
    
    /// Determines if Bluetooth Low Energy is supported on this device
    /// - Returns: True if BLE is supported (regardless of power state), false otherwise
    @MainActor
    private static func getBluetoothStatus() async -> Bool {
        let manager = CBCentralManager(delegate: nil, queue: nil)
        
        // Wait for the manager state to be determined if it's currently unknown
        if manager.state == .unknown {
            await waitForBluetoothState(manager)
        }
        
        let state = manager.state
        
        // BLE is considered "supported" if the state is either powered on or off
        // (as opposed to unsupported, unauthorized, etc.)
        let isBLESupported = state == .poweredOn || state == .poweredOff
        
        return isBLESupported
    }
    
    /// Waits for the Bluetooth manager to determine its state
    /// - Parameter manager: The CBCentralManager to monitor
    @MainActor
    private static func waitForBluetoothState(_ manager: CBCentralManager) async {
        await withCheckedContinuation { continuation in
            let delegate = BluetoothStateDelegate {
                continuation.resume()
            }
            manager.delegate = delegate
            
            // Retain the delegate during the async operation to prevent deallocation
            objc_setAssociatedObject(manager, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Converts CBManagerState to a human-readable string
    /// - Parameter state: The Bluetooth manager state
    /// - Returns: String representation of the state
    /// - Note: This method is kept for potential debugging use
    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "powered_off"
        case .poweredOn: return "powered_on"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - BluetoothStateDelegate

/// Private delegate class for monitoring Bluetooth state changes.
///
/// This delegate is used temporarily to wait for the Bluetooth manager
/// to determine its initial state when it starts as `.unknown`.
private class BluetoothStateDelegate: NSObject, CBCentralManagerDelegate {
    private let completion: () -> Void
    
    /// Initializes the delegate with a completion handler
    /// - Parameter completion: Closure to call when state is determined
    init(completion: @escaping () -> Void) {
        self.completion = completion
    }
    
    /// Called when the central manager's state is updated
    /// - Parameter central: The central manager whose state changed
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        completion()
    }
}
