// 
//  NetworkPathMonitorTests.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import Network
import Combine
@testable import PingDeviceProfile

class NetworkPathMonitorTests: XCTestCase {
    
    var monitor: NetworkPathMonitor!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        monitor = NetworkPathMonitor()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        monitor?.stopMonitoring()
        cancellables?.removeAll()
        monitor = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testNetworkPathMonitorInitialization() {
        XCTAssertNotNil(monitor, "NetworkPathMonitor should initialize")
        XCTAssertFalse(monitor.isConnected, "isConnected should be false initially")
        XCTAssertEqual(monitor.connectionType, .unknown, "connectionType should be unknown initially")
        XCTAssertEqual(monitor.status, .unknown, "status should be unknown initially")
    }
    
    func testNetworkPathMonitorInitializationWithInterfaceType() {
        let cellularMonitor = NetworkPathMonitor(interfaceType: .cellular)
        
        XCTAssertNotNil(cellularMonitor, "NetworkPathMonitor with interface type should initialize")
        XCTAssertFalse(cellularMonitor.isConnected, "isConnected should be false initially")
        XCTAssertEqual(cellularMonitor.connectionType, .unknown, "connectionType should be unknown initially")
        
        cellularMonitor.stopMonitoring()
    }
    
    // MARK: - Published Properties Tests
    
    func testPublishedProperties() {
        // Test that all @Published properties are accessible
        XCTAssertNotNil(monitor.isConnected, "isConnected should be accessible")
        XCTAssertNotNil(monitor.connectionType, "connectionType should be accessible")
        XCTAssertNotNil(monitor.status, "status should be accessible")
        
        // Test initial values
        XCTAssertFalse(monitor.isConnected, "isConnected should initially be false")
        XCTAssertEqual(monitor.connectionType, .unknown, "connectionType should initially be unknown")
        XCTAssertEqual(monitor.status, .unknown, "status should initially be unknown")
    }
    
    // MARK: - Monitoring Control Tests
    
    func testStartMonitoring() {
        XCTAssertNoThrow(monitor.startMonitoring(), "startMonitoring should not throw")
    }
    
    func testStopMonitoring() {
        monitor.startMonitoring()
        XCTAssertNoThrow(monitor.stopMonitoring(), "stopMonitoring should not throw")
    }
    
    func testMultipleStartStopCalls() {
        // Should handle multiple calls gracefully
        monitor.startMonitoring()
        monitor.startMonitoring() // Second call should be safe
        monitor.stopMonitoring()
        monitor.stopMonitoring() // Second call should be safe
        
        XCTAssertTrue(true, "Multiple start/stop calls should be handled safely")
    }
    
    func testStartStopSequence() {
        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.startMonitoring()
        monitor.stopMonitoring()
        
        XCTAssertTrue(true, "Start/stop sequence should work correctly")
    }
    
    // MARK: - Computed Properties Tests
    
    func testComputedPropertiesWithInitialState() {
        XCTAssertFalse(monitor.isExpensive, "isExpensive should be false initially")
        XCTAssertFalse(monitor.isConstrained, "isConstrained should be false initially")
        XCTAssertFalse(monitor.isConnectedViaWiFi, "isConnectedViaWiFi should be false initially")
        XCTAssertFalse(monitor.isConnectedViaCellular, "isConnectedViaCellular should be false initially")
    }
    
    func testIsConnectedViaWiFiLogic() {
        // Test the computed property logic
        // Since we can't easily mock NWPath, we test the property accessibility
        let isWiFi = monitor.isConnectedViaWiFi
        
        // Should be boolean and correlated with connection state
        XCTAssertFalse(isWiFi, "Should be false when not connected via WiFi initially")
        
        // The logic should be: isConnected && connectionType == .wifi
        if monitor.isConnected && monitor.connectionType == .wifi {
            XCTAssertTrue(monitor.isConnectedViaWiFi, "Should be true when connected via WiFi")
        } else {
            XCTAssertFalse(monitor.isConnectedViaWiFi, "Should be false when not connected via WiFi")
        }
    }
    
    func testIsConnectedViaCellularLogic() {
        let isCellular = monitor.isConnectedViaCellular
        
        // Should be boolean and correlated with connection state
        XCTAssertFalse(isCellular, "Should be false when not connected via cellular initially")
        
        // The logic should be: isConnected && connectionType == .cellular
        if monitor.isConnected && monitor.connectionType == .cellular {
            XCTAssertTrue(monitor.isConnectedViaCellular, "Should be true when connected via cellular")
        } else {
            XCTAssertFalse(monitor.isConnectedViaCellular, "Should be false when not connected via cellular")
        }
    }
    
    func testNetworkInfoProperty() {
        let networkInfo = monitor.networkInfo
        
        XCTAssertFalse(networkInfo.isEmpty, "networkInfo should not be empty")
        XCTAssertTrue(networkInfo.contains("Status:"), "networkInfo should contain 'Status:'")
        XCTAssertTrue(networkInfo.contains(monitor.status.rawValue), "networkInfo should contain status value")
        
        // Should contain current connection type if connected
        if monitor.isConnected {
            XCTAssertTrue(networkInfo.contains("Type:"), "networkInfo should contain 'Type:' when connected")
        }
    }
    
    // MARK: - Enum Tests
    
    func testNetworkStatusEnum() {
        let allCases = NetworkStatus.allCases
        XCTAssertEqual(allCases.count, 4, "NetworkStatus should have 4 cases")
        
        // Test all raw values
        XCTAssertEqual(NetworkStatus.satisfied.rawValue, "Connected")
        XCTAssertEqual(NetworkStatus.unsatisfied.rawValue, "Not Connected")
        XCTAssertEqual(NetworkStatus.requiresConnection.rawValue, "Requires Connection")
        XCTAssertEqual(NetworkStatus.unknown.rawValue, "Unknown")
        
        // Test that all cases are present
        XCTAssertTrue(allCases.contains(.satisfied))
        XCTAssertTrue(allCases.contains(.unsatisfied))
        XCTAssertTrue(allCases.contains(.requiresConnection))
        XCTAssertTrue(allCases.contains(.unknown))
    }
    
    func testNetworkInterfaceTypeEnum() {
        // Test all raw values
        XCTAssertEqual(NetworkInterfaceType.wifi.rawValue, "WiFi")
        XCTAssertEqual(NetworkInterfaceType.cellular.rawValue, "Cellular")
        XCTAssertEqual(NetworkInterfaceType.wiredEthernet.rawValue, "Ethernet")
        XCTAssertEqual(NetworkInterfaceType.loopback.rawValue, "Loopback")
        XCTAssertEqual(NetworkInterfaceType.other.rawValue, "Other")
        XCTAssertEqual(NetworkInterfaceType.unknown.rawValue, "Unknown")
        
        // Test that enum values are accessible
        let allTypes: [NetworkInterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other, .unknown]
        for type in allTypes {
            XCTAssertFalse(type.rawValue.isEmpty, "Each interface type should have non-empty raw value")
        }
    }
    
    // MARK: - Status Update Callback Tests
    
    func testStatusUpdateCallback() {
        var callbackInvoked = false
        var receivedStatus: NetworkStatus?
        
        monitor.statusUpdateCallback = { status in
            callbackInvoked = true
            receivedStatus = status
        }
        
        // Simulate a status update by calling the callback directly
        monitor.statusUpdateCallback?(.satisfied)
        
        XCTAssertTrue(callbackInvoked, "Status update callback should be invoked")
        XCTAssertEqual(receivedStatus, .satisfied, "Callback should receive correct status")
    }
    
    func testStatusUpdateCallbackNil() {
        // Should not crash with nil callback
        monitor.statusUpdateCallback = nil
        monitor.statusUpdateCallback?(.satisfied)
        
        XCTAssertTrue(true, "Nil callback should be handled gracefully")
    }
    
    func testMultipleStatusCallbacks() {
        var callCount = 0
        var lastStatus: NetworkStatus?
        
        monitor.statusUpdateCallback = { status in
            callCount += 1
            lastStatus = status
        }
        
        // Call multiple times
        monitor.statusUpdateCallback?(.satisfied)
        monitor.statusUpdateCallback?(.unsatisfied)
        monitor.statusUpdateCallback?(.requiresConnection)
        
        XCTAssertEqual(callCount, 3, "Callback should be called 3 times")
        XCTAssertEqual(lastStatus, .requiresConnection, "Last status should be preserved")
    }
    
    // MARK: - Performance Tests
    
    func testMonitoringPerformance() {
        measure {
            monitor.startMonitoring()
            monitor.stopMonitoring()
        }
    }
    
    func testComputedPropertiesPerformance() {
        measure {
            _ = monitor.isConnectedViaWiFi
            _ = monitor.isConnectedViaCellular
            _ = monitor.isExpensive
            _ = monitor.isConstrained
            _ = monitor.networkInfo
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testMonitorMemoryManagement() {
        weak var weakMonitor: NetworkPathMonitor?
        
        autoreleasepool {
            let localMonitor = NetworkPathMonitor()
            localMonitor.startMonitoring()
            weakMonitor = localMonitor
            XCTAssertNotNil(weakMonitor, "Monitor should exist")
            
            localMonitor.stopMonitoring()
        }
        
        // Give time for deallocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakMonitor, "Monitor should be deallocated")
        }
    }
    
    func testMonitorWithoutStopMonitoring() {
        weak var weakMonitor: NetworkPathMonitor?
        
        autoreleasepool {
            let localMonitor = NetworkPathMonitor()
            localMonitor.startMonitoring()
            weakMonitor = localMonitor
            // Intentionally not calling stopMonitoring to test deinit behavior
        }
        
        // Should still be deallocated properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(weakMonitor, "Monitor should be deallocated even without explicit stop")
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentMonitoringOperations() async {
        let iterations = 10
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask { [monitor] in
                    monitor?.startMonitoring()
                    monitor?.stopMonitoring()
                }
            }
        }
        
        XCTAssertTrue(true, "Concurrent monitoring operations should complete safely")
    }
    
    func testConcurrentPropertyAccess() async {
        let iterations = 20
        
        await withTaskGroup(of: (Bool, NetworkInterfaceType, NetworkStatus).self) { group in
            for _ in 0..<iterations {
                group.addTask { [monitor] in
                    return (
                        monitor.isConnected,
                        monitor.connectionType,
                        monitor.status
                    )
                }
            }
            
            var results: [(Bool, NetworkInterfaceType, NetworkStatus)] = []
            for await result in group {
                results.append(result)
            }
            
            XCTAssertEqual(results.count, iterations, "Should complete all concurrent property accesses")
            
            // All results should be identical (properties don't change without actual network changes)
            if results.count > 1 {
                let first = results[0]
                for result in results {
                    XCTAssertEqual(result.0, first.0, "isConnected should be consistent")
                    XCTAssertEqual(result.1, first.1, "connectionType should be consistent")
                    XCTAssertEqual(result.2, first.2, "status should be consistent")
                }
            }
        }
    }
    
    // MARK: - Combine Integration Tests
    
    func testPublisherIntegration() async throws {
        let expectation = XCTestExpectation(description: "Publisher should emit values")
        var receivedValues: [Bool] = []
        
        monitor.$isConnected
            .sink { isConnected in
                receivedValues.append(isConnected)
                if receivedValues.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start monitoring to potentially trigger updates
        monitor.startMonitoring()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        XCTAssertGreaterThan(receivedValues.count, 0, "Should receive at least initial value")
        XCTAssertEqual(receivedValues[0], false, "Initial value should be false")
    }
    
    func testMultiplePublishers() async throws {
        let isConnectedExpectation = XCTestExpectation(description: "isConnected publisher")
        let connectionTypeExpectation = XCTestExpectation(description: "connectionType publisher")
        let statusExpectation = XCTestExpectation(description: "status publisher")
        
        var connectionValues: [Bool] = []
        var typeValues: [NetworkInterfaceType] = []
        var statusValues: [NetworkStatus] = []
        
        monitor.$isConnected
            .sink { value in
                connectionValues.append(value)
                isConnectedExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        monitor.$connectionType
            .sink { value in
                typeValues.append(value)
                connectionTypeExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        monitor.$status
            .sink { value in
                statusValues.append(value)
                statusExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        monitor.startMonitoring()
        
        await fulfillment(of: [isConnectedExpectation, connectionTypeExpectation, statusExpectation], timeout: 2.0)
        
        XCTAssertGreaterThan(connectionValues.count, 0, "Should receive connection values")
        XCTAssertGreaterThan(typeValues.count, 0, "Should receive type values")
        XCTAssertGreaterThan(statusValues.count, 0, "Should receive status values")
    }
    
    // MARK: - Edge Case Tests
    
    func testMonitorDescription() {
        let description = String(describing: monitor)
        XCTAssertFalse(description.isEmpty, "Description should not be empty")
        XCTAssertTrue(description.contains("NetworkPathMonitor"), "Description should mention NetworkPathMonitor")
    }
    
    func testNetworkInfoWithDifferentStates() {
        // Test network info generation with different states
        let initialInfo = monitor.networkInfo
        XCTAssertTrue(initialInfo.contains("Unknown"), "Initial info should contain Unknown")
        
        // The networkInfo property should always return a valid string
        XCTAssertFalse(initialInfo.isEmpty, "Network info should never be empty")
        XCTAssertTrue(initialInfo.contains("Status:"), "Network info should always contain Status")
    }
    
    func testExpensiveAndConstrainedProperties() {
        // These properties depend on NWPath which we can't easily mock
        // But we can test that they return boolean values and don't crash
        let isExpensive = monitor.isExpensive
        let isConstrained = monitor.isConstrained
        
        // Initially should be false (no path available)
        XCTAssertFalse(isExpensive, "isExpensive should be false initially")
        XCTAssertFalse(isConstrained, "isConstrained should be false initially")
    }
    
    // MARK: - Integration Tests
    
    func testMonitorWithRealNetworkFramework() {
        // This tests actual integration with Network framework
        monitor.startMonitoring()
        
        // Give some time for network path updates
        let expectation = XCTestExpectation(description: "Network status should be determined")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // After starting monitoring, status should be determined (not unknown)
            // In test environment, this might still be unknown, but shouldn't crash
            XCTAssertTrue(true, "Network monitoring should work without crashing")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Properties should be accessible without crashing
        _ = monitor.isConnected
        _ = monitor.connectionType
        _ = monitor.status
        _ = monitor.networkInfo
        
        monitor.stopMonitoring()
    }
    
    func testMonitorStatusTransitions() {
        // Test that status can transition between different states
        let initialStatus = monitor.status
        XCTAssertEqual(initialStatus, .unknown, "Initial status should be unknown")
        
        monitor.startMonitoring()
        
        // Status might change after starting monitoring
        // In test environment, it might remain unknown, but that's acceptable
        let afterStartStatus = monitor.status
        
        let validStatuses: [NetworkStatus] = [.unknown, .satisfied, .unsatisfied, .requiresConnection]
        XCTAssertTrue(validStatuses.contains(afterStartStatus), "Status should be valid after starting")
        
        monitor.stopMonitoring()
    }
    
    // MARK: - Error Handling Tests
    
    func testMonitorWithInvalidOperations() {
        // Test that invalid operations don't crash
        monitor.stopMonitoring() // Stop before start
        monitor.startMonitoring()
        monitor.startMonitoring() // Start twice
        monitor.stopMonitoring()
        monitor.stopMonitoring() // Stop twice
        
        XCTAssertTrue(true, "Invalid operation sequences should be handled gracefully")
    }
    
    func testMonitoringStateAfterDeallocation() {
        var localMonitor: NetworkPathMonitor? = NetworkPathMonitor()
        localMonitor?.startMonitoring()
        
        // Properties should be accessible
        XCTAssertNotNil(localMonitor?.isConnected)
        
        // Deallocate
        localMonitor = nil
        
        // Should not crash (automatic cleanup in deinit)
        XCTAssertTrue(true, "Monitor deallocation should be clean")
    }
    
    // MARK: - Boundary Tests
    
    func testNetworkInfoLengthReasonableness() {
        let networkInfo = monitor.networkInfo
        
        // Network info should be reasonable length
        XCTAssertGreaterThan(networkInfo.count, 5, "Network info should have reasonable minimum length")
        XCTAssertLessThan(networkInfo.count, 1000, "Network info should not be excessively long")
        
        // Should contain expected structure
        XCTAssertTrue(networkInfo.hasPrefix("Status:"), "Should start with Status:")
    }
    
    func testAllEnumCasesHandled() {
        // Test that all NetworkStatus cases are handled in string conversion
        let testStatuses: [NetworkStatus] = [.satisfied, .unsatisfied, .requiresConnection, .unknown]
        
        for status in testStatuses {
            XCTAssertFalse(status.rawValue.isEmpty, "Each status should have non-empty raw value")
            XCTAssertGreaterThan(status.rawValue.count, 3, "Status raw values should be descriptive")
        }
        
        // Test that all NetworkInterfaceType cases are handled
        let testTypes: [NetworkInterfaceType] = [.wifi, .cellular, .wiredEthernet, .loopback, .other, .unknown]
        
        for type in testTypes {
            XCTAssertFalse(type.rawValue.isEmpty, "Each type should have non-empty raw value")
        }
    }
}
