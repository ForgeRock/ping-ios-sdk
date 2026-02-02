// 
//  BluetoothCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CoreBluetooth


// MARK: - BluetoothStateProvider Protocol

/// Protocol for providing Bluetooth state detection (allows for mocking)
public protocol BluetoothStateProvider: Sendable {
    /// Returns whether Bluetooth is supported on the device
    func getBluetoothSupported() async -> Bool
}

// MARK: - BluetoothCollector

/// Collector for Bluetooth Low Energy (BLE) capability information.
///
/// This collector determines whether the device supports Bluetooth Low Energy
/// by checking the CoreBluetooth framework's central manager state.
/// It provides information about BLE support without requiring location permissions.
public class BluetoothCollector: DeviceCollector, @unchecked Sendable {
    public typealias DataType = BluetoothInfo
    
    /// Unique identifier for bluetooth capability data
    public let key = "bluetooth"
    
    /// Dependency injection for Bluetooth state provider
    private let stateProvider: BluetoothStateProvider
    
    /// Collects Bluetooth capability information
    /// - Returns: BluetoothInfo containing support status
    public func collect() async -> BluetoothInfo? {
        let supported = await stateProvider.getBluetoothSupported()
        return BluetoothInfo(supported: supported)
    }
    
    /// Initializes a new instance with optional state provider (for testing)
    /// - Parameter stateProvider: Custom state provider. If nil, uses real CoreBluetooth implementation
    public init(stateProvider: BluetoothStateProvider? = nil) {
        if let stateProvider = stateProvider {
            self.stateProvider = stateProvider
        } else {
            self.stateProvider = RealBluetoothStateProvider()
        }
    }
}

// MARK: - BluetoothInfo

/// Information about device Bluetooth Low Energy capabilities.
public struct BluetoothInfo: Codable, Sendable {
    /// Whether the device supports Bluetooth Low Energy
    /// - Note: This indicates hardware support, not current power state or permissions
    public let supported: Bool
}

// MARK: - Real Implementation

/// Real Bluetooth state provider using CoreBluetooth
actor RealBluetoothStateProvider: BluetoothStateProvider {
    func getBluetoothSupported() async -> Bool {
        return await getBluetoothStatus()
    }
    
    /// Determines if Bluetooth Low Energy is supported on this device
    /// - Returns: True if BLE is supported (regardless of power state), false otherwise
    @MainActor
    private func getBluetoothStatus() async -> Bool {
        let delegateBridge = BluetoothDelegateBridge()
        let manager = CBCentralManager(delegate: delegateBridge, queue: nil)
        manager.delegate = delegateBridge
        
        // Await a definitive state (not .unknown or .resetting)
        for await state in delegateBridge.stream {
            // Skip transient states and wait for a definitive answer
            switch state {
            case .unknown, .resetting:
                // Continue waiting for a definitive state
                continue
            case .poweredOn, .poweredOff:
                // BLE is supported (hardware exists, regardless of power state)
                return true
            case .unsupported:
                // Device doesn't support BLE
                return false
            case .unauthorized:
                // BLE hardware exists but app lacks permission - still means BLE is supported
                return true
            @unknown default:
                // For future states, assume not supported to be safe
                return false
            }
        }
        
        // Fallback if the stream finishes without yielding a definitive value
        return false
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
        
        // Only finish the stream for definitive states (not transient ones)
        switch central.state {
        case .unknown, .resetting:
            // Don't finish - wait for a definitive state
            break
        default:
            // Definitive state received, finish the stream
            continuation?.finish()
        }
    }
}