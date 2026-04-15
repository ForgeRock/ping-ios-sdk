/*
 * Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import XCTest
import CoreBluetooth
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingOidc
@testable import PingLogger
@testable import PingDeviceProfile
import CoreLocation

class DeviceProfileCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "DeviceProfileCallbackTest"
    
    @MainActor
    func testDeviceProfileCallbackWithDefaultCollectors() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        // The first callback is a ChoiceCallback (choose to collect location or not...)
        guard let choiceCallback = nextNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            return
        }
        
        // Select "Yes" - collect location data...
        choiceCallback.selectedIndex = 0
        
        // Submit callback and expect SuccessNode
        guard let nextNode = await nextNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting the choice.")
            return
        }
        
        // Access the next callback and ensure it's a DeviceProfile Callback
        guard let deviceProfileCallback = nextNode.callbacks.first as? DeviceProfileCallback else {
            XCTFail("Expected DeviceProfileCallback")
            return
        }
        
        // Assert device profile callback properties
        XCTAssertEqual(deviceProfileCallback.message, "Collecting profile ...")
        XCTAssertTrue(deviceProfileCallback.location)
        XCTAssertTrue(deviceProfileCallback.metadata)
        
        let mockCLLocationManager = MockLocationManager()
        mockCLLocationManager.mockLocationServicesEnabled = true
        mockCLLocationManager.mockAuthorizationStatus = .authorizedWhenInUse
        let expectedLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        mockCLLocationManager.mockLocation = expectedLocation
        MockLocationManager.shared = mockCLLocationManager
        
        // Create LocationManager with the mock
        let manager = LocationManager(
            locationManager: mockCLLocationManager,
            locationManagerType: MockLocationManager.self
        )
        
        // Collect device profile using the devault collectors...
        let result = await deviceProfileCallback.collect { config in
            config.collectors {
                return DefaultDeviceCollector.defaultDeviceCollectorsForTesting()
            }
            config.locationCollector = LocationCollector(locationManager: manager)
        }
        
        switch result {
        case .success(let profile):
            XCTAssertTrue(profile.keys.contains("identifier"))
            XCTAssertTrue(profile.keys.contains("location"))
            XCTAssertTrue(profile.keys.contains("metadata"))
            XCTAssertTrue(profile.keys.contains("version"))
            
            let metadata = profile["metadata"] as! [String: Any]
            XCTAssertTrue(metadata.keys.contains("platform"))
            XCTAssertTrue(metadata.keys.contains("hardware"))
            XCTAssertTrue(metadata.keys.contains("network"))
            XCTAssertTrue(metadata.keys.contains("telephony"))
            XCTAssertTrue(metadata.keys.contains("bluetooth"))
            XCTAssertTrue(metadata.keys.contains("browser"))
            
            let platform = metadata["platform"] as? [String: Any]
            let brand = platform?["brand"] as? String
            XCTAssertNotNil(brand)
            XCTAssertFalse(brand!.isEmpty)
            
            let hardware = metadata["hardware"] as! [String: Any]
            let manufacturer = hardware["manufacturer"] as? String
            XCTAssertNotNil(manufacturer)
            XCTAssertFalse(manufacturer!.isEmpty)
            
        case .failure(let error):
            XCTFail("Unexpected failure during device profile collection. Error: \(error)")
            return
        }
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting")
            return
        }
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceProfileCallbackWithCustomCollectors() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        // The first callback is a ChoiceCallback (choose to collect location or not)
        guard let choiceCallback = nextNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            return
        }
        
        // Select "No" - do NOT collect location data...
        choiceCallback.selectedIndex = 1
        
        // Submit callback and expect SuccessNode
        guard let nextNode = await nextNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting the choice.")
            return
        }
        
        // Access the next callback and ensure it's a DeviceProfile Callback
        guard let deviceProfileCallback = nextNode.callbacks.first as? DeviceProfileCallback else {
            XCTFail("Expected DeviceProfileCallback")
            return
        }
        
        // Assert device profile callback properties
        XCTAssertTrue(deviceProfileCallback.message.isEmpty)
        XCTAssertFalse(deviceProfileCallback.location)
        XCTAssertTrue(deviceProfileCallback.metadata)
        
        let result = await deviceProfileCallback.collect { config in
            config.collectors {
                return [
                    PlatformCollector(),
                    HardwareCollector()
                ]
            }
        }
        
        switch result {
        case .success(let profile):
            // Assertions based on the example profile
            XCTAssertTrue(profile.keys.contains("identifier"))
            XCTAssertFalse(profile.keys.contains("location"))
            XCTAssertTrue(profile.keys.contains("metadata"))
            XCTAssertTrue(profile.keys.contains("version"))
            
            let metadata = profile["metadata"] as! [String: Any]
            XCTAssertTrue(metadata.keys.contains("platform"))
            XCTAssertTrue(metadata.keys.contains("hardware"))
            
            // Ensure other collectors are not present
            XCTAssertFalse(metadata.keys.contains("network"))
            XCTAssertFalse(metadata.keys.contains("telephony"))
            XCTAssertFalse(metadata.keys.contains("bluetooth"))
            XCTAssertFalse(metadata.keys.contains("browser"))
            
            let platform = metadata["platform"] as! [String: Any]
            let brand = platform["brand"] as? String
            XCTAssertNotNil(brand)
            XCTAssertFalse(brand!.isEmpty)
            
            let hardware = metadata["hardware"] as! [String: Any]
            let manufacturer = hardware["manufacturer"] as? String
            XCTAssertNotNil(manufacturer)
            XCTAssertFalse(manufacturer!.isEmpty)
            
        case .failure(let error):
            XCTFail("Unexpected failure during device profile collection. Error: \(error)")
            return
        }
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting")
            return
        }
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testDeviceProfileCallbackWithSimpleCustomCollector() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        // The first callback is a ChoiceCallback (choose to collect location or not)
        guard let choiceCallback = nextNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            return
        }
        
        // Select "No" - do NOT collect location data...
        choiceCallback.selectedIndex = 1
        
        // Submit callback and expect SuccessNode
        guard let nextNode = await nextNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting the choice.")
            return
        }
        
        // Access the next callback and ensure it's a DeviceProfile Callback
        guard let deviceProfileCallback = nextNode.callbacks.first as? DeviceProfileCallback else {
            XCTFail("Expected DeviceProfileCallback")
            return
        }
        
        struct BatteryCollector: DeviceCollector {
            typealias DataType = BatteryInfo
            
            let key = "battery"
            
            func collect() async throws -> BatteryInfo? {
                return BatteryInfo(
                    level: 90.5,
                    isCharging: true,
                    capacity: 4000
                )
            }
        }
        
        struct BatteryInfo: Codable {
            let level: Float
            let isCharging: Bool
            let capacity: Int
        }
        
        // Use custom collector...
        let result = await deviceProfileCallback.collect { config in
            config.collectors {
                return [
                    BatteryCollector()
                ]
            }
        }
        
        switch result {
        case .success(let profile):
            // Assertions based on the example profile
            XCTAssertTrue(profile.keys.contains("identifier"))
            XCTAssertFalse(profile.keys.contains("location"))
            XCTAssertTrue(profile.keys.contains("metadata"))
            XCTAssertTrue(profile.keys.contains("version"))
            
            let metadata = profile["metadata"] as! [String: Any]
            XCTAssertTrue(metadata.keys.contains("battery"))
            
            // Ensure other collectors are not present
            XCTAssertFalse(metadata.keys.contains("platform"))
            XCTAssertFalse(metadata.keys.contains("hardware"))
            XCTAssertFalse(metadata.keys.contains("network"))
            XCTAssertFalse(metadata.keys.contains("telephony"))
            XCTAssertFalse(metadata.keys.contains("bluetooth"))
            XCTAssertFalse(metadata.keys.contains("browser"))
            
            let battery = metadata["battery"] as? [String: Any]
            XCTAssertEqual(battery?["level"] as? Float, 90.5)
            XCTAssertEqual(battery?["isCharging"] as? Bool, true)
            XCTAssertEqual(battery?["capacity"] as? Int, 4000)
            
        case .failure(let error):
            XCTFail("Unexpected failure during device profile collection. Error: \(error)")
            return
        }
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting")
            return
        }
        
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}

/// Extension to provide default collectors for testing
extension DefaultDeviceCollector {
    public static func defaultDeviceCollectorsForTesting() -> [any DeviceCollector] {
        return [
            PlatformCollector(),
            HardwareCollector(),
            BrowserCollector(),
            TelephonyCollector(),
            NetworkCollector(),
            BluetoothCollector(stateProvider: MockBluetoothStateProvider()),
        ]
    }
}

/// Mock Bluetooth state provider for testing (no system prompts)
struct MockBluetoothStateProvider: BluetoothStateProvider {
    var mockState: CBManagerState = .poweredOn
    
    func getBluetoothSupported() async -> Bool {
        let isBLESupported = mockState == .poweredOn || mockState == .poweredOff
        return isBLESupported
    }
}

/// Mock implementation for testing location scenarios
@MainActor class MockLocationManager: @preconcurrency LocationManagerProtocol {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    
    // Test configuration properties
    var mockAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var mockLocationServicesEnabled: Bool = true
    var mockLocation: CLLocation?
    var mockError: Error?
    var shouldDelayResponse: Bool = false
    
    // Call tracking for verification
    var requestLocationCallCount = 0
    var requestWhenInUseAuthorizationCallCount = 0
    var requestAlwaysAuthorizationCallCount = 0
    
    // Shared state for static methods (used in tests)
    @MainActor static var shared: MockLocationManager?
    
    @MainActor static func locationServicesEnabled() -> Bool {
        return shared?.mockLocationServicesEnabled ?? true
    }
    
    @MainActor static func authorizationStatus() -> CLAuthorizationStatus {
        return shared?.mockAuthorizationStatus ?? .notDetermined
    }
    
    func requestLocation() {
        requestLocationCallCount += 1
        
        let simulateResponse = {
            if let error = self.mockError {
                self.delegate?.locationManager?(CLLocationManager(), didFailWithError: error)
            } else if let location = self.mockLocation {
                self.delegate?.locationManager?(CLLocationManager(), didUpdateLocations: [location])
            } else {
                // No location set - simulate a failure
                let error = NSError(domain: kCLErrorDomain,
                                   code: CLError.locationUnknown.rawValue,
                                   userInfo: [NSLocalizedDescriptionKey: "No mock location configured"])
                self.delegate?.locationManager?(CLLocationManager(), didFailWithError: error)
            }
        }
        
        // Always respond asynchronously to match real CoreLocation behavior
        let delay = shouldDelayResponse ? 0.1 : 0.01
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            simulateResponse()
        }
    }
    
    func requestWhenInUseAuthorization() {
        requestWhenInUseAuthorizationCallCount += 1
        
        // If currently notDetermined, grant permission automatically
        if mockAuthorizationStatus == .notDetermined {
            mockAuthorizationStatus = .authorizedWhenInUse
        }
        
        // Simulate authorization change
        DispatchQueue.main.async {
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }
    
    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCallCount += 1
        
        // If currently notDetermined, grant permission automatically
        if mockAuthorizationStatus == .notDetermined {
            mockAuthorizationStatus = .authorizedAlways
        }
        
        // Simulate authorization change
        DispatchQueue.main.async {
            self.delegate?.locationManagerDidChangeAuthorization?(CLLocationManager())
        }
    }
}
