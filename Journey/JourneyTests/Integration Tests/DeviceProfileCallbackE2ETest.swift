/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingOidc
@testable import PingLogger
@testable import PingDeviceProfile

class DeviceProfileCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "DeviceProfileCallbackTest"
    
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
        
        // Collect device profile using the devault collectors...
        let result = await deviceProfileCallback.collect { config in
            config.collectors {
                return DefaultDeviceCollector.defaultDeviceCollectors()
            }
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
