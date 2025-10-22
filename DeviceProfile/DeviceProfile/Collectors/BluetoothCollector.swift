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
public class BluetoothCollector: DeviceCollector {
    public typealias DataType = BluetoothInfo
    
    /// Unique identifier for bluetooth capability data
    public let key = "bluetooth"
    
    /// Collects Bluetooth capability information
    /// - Returns: BluetoothInfo containing support status
    public func collect() async -> BluetoothInfo? {
        return await BluetoothInfo()
    }
    
    /// Initializes a new instance
    public init() {}
}

// MARK: - BluetoothInfo

/// Information about device Bluetooth Low Energy capabilities.
///
/// This structure contains the results of Bluetooth capability detection,
/// indicating whether the device supports BLE functionality.
public struct BluetoothInfo: Codable {
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
        let delegateBridge = BluetoothDelegateBridge()
        let manager = CBCentralManager(delegate: delegateBridge, queue: nil)
        manager.delegate = delegateBridge
        
        // Await the first value emitted by the stream
        for await state in delegateBridge.stream {
            // This loop will only run once because we call continuation.finish()
            // `manager` and `delegateBridge` are kept alive until this point.
            let isBLESupported = state == .poweredOn || state == .poweredOff
            return isBLESupported
        }
        
        // Fallback if the stream finishes without yielding a value
        return false
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

// MARK: - BluetoothDelegate

/// Private delegate class for monitoring Bluetooth state changes.
///
/// This delegate is used temporarily to wait for the Bluetooth manager
/// to determine its initial state when it starts as `.unknown`.
@MainActor
private class BluetoothDelegateBridge: NSObject, @preconcurrency CBCentralManagerDelegate {
    
    // The continuation to push state updates into the stream
    private var continuation: AsyncStream<CBManagerState>.Continuation?
    
    // The stream that async functions can listen to
    lazy var stream: AsyncStream<CBManagerState> = {
        AsyncStream { self.continuation = $0 }
    }()
    
    // The delegate method that fires when the state changes
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Push the new state into the stream
        continuation?.yield(central.state)
        
        // Since we only need the *first* state update, we can finish the stream.
        continuation?.finish()
    }
}
