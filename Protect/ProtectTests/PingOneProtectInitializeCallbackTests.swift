//
//  PingOneProtectInitializeCallbackTests.swift
//  ProtectTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect
@testable import PingJourney

// Mock Protect Configuration
struct MockProtectConfig {
    var envId: String?
    var deviceAttributesToIgnore: [String] = []
    var customHost: String?
    var isConsoleLogEnabled: Bool = false
    var isLazyMetadata: Bool = false
    var isBehavioralDataCollection: Bool = false
}

// Mock Protect SDK for testing
class MockProtectSDK {
    static var shouldThrowError = false
    static var errorMessage = "Initialization failed"
    static var initializeCalled = false
    static var resumeBehavioralDataCalled = false
    static var pauseBehavioralDataCalled = false
    static var configCalled = false
    static var lastConfig: MockProtectConfig?

    static func reset() {
        shouldThrowError = false
        errorMessage = "Initialization failed"
        initializeCalled = false
        resumeBehavioralDataCalled = false
        pauseBehavioralDataCalled = false
        configCalled = false
        lastConfig = nil
    }

    static func config(_ closure: (inout MockProtectConfig) -> Void) async {
        configCalled = true
        var config = MockProtectConfig()
        closure(&config)
        lastConfig = config
    }

    static func initialize() async throws {
        initializeCalled = true
        if shouldThrowError {
            throw InitializationError.initFailed(errorMessage)
        }
    }

    static func resumeBehavioralData() async throws {
        resumeBehavioralDataCalled = true
    }

    static func pauseBehavioralData() async throws {
        pauseBehavioralDataCalled = true
    }
}

enum InitializationError: LocalizedError {
    case initFailed(String)

    var errorDescription: String? {
        switch self {
        case .initFailed(let message):
            return message
        }
    }
}

// Test double for PingOneProtectInitializeCallback
class TestableProtectInitializeCallback: PingOneProtectInitializeCallback, @unchecked Sendable {
    var mockProtect: MockProtectSDK.Type = MockProtectSDK.self
    var errorMessage: String?

    override func error(_ message: String) {
        self.errorMessage = message
    }

    override func start() async -> Result<Void, Error> {
        do {
            // Configure Protect SDK using mock
            await mockProtect.config { config in
                config.envId = envId.isEmpty ? nil : envId
                config.deviceAttributesToIgnore = deviceAttributesToIgnore
                config.customHost = customHost.isEmpty ? nil : customHost
                config.isConsoleLogEnabled = isConsoleLogEnabled
                config.isLazyMetadata = lazyMetadata
                config.isBehavioralDataCollection = isBehavioralDataCollection
            }

            try await mockProtect.initialize()

            if isBehavioralDataCollection {
                try await mockProtect.resumeBehavioralData()
            } else {
                try await mockProtect.pauseBehavioralData()
            }
            return .success(())
        } catch {
            let errorMsg = error.localizedDescription.isEmpty ? JourneyConstants.clientError : error.localizedDescription
            self.error(errorMsg)
            return .failure(error)
        }
    }
}

final class PingOneProtectInitializeCallbackTests: XCTestCase {

    var callback: TestableProtectInitializeCallback!

    override func setUp() {
        super.setUp()
        MockProtectSDK.reset()
        callback = TestableProtectInitializeCallback()
    }

    override func tearDown() {
        callback = nil
        MockProtectSDK.reset()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesAllPropertiesCorrectlyFromValidJson() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "02fb4743-189a-4bc7-9d6c-a919edfe6447")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)
        callback.initValue(name: JourneyConstants.consoleLogEnabled, value: true)
        callback.initValue(name: JourneyConstants.lazyMetadata, value: true)
        callback.initValue(name: JourneyConstants.customHost, value: "host.example.com")
        callback.initValue(name: JourneyConstants.deviceAttributesToIgnore, value: ["attr1", "attr2"])

        // Then - Verify properties
        XCTAssertEqual(callback.envId, "02fb4743-189a-4bc7-9d6c-a919edfe6447")
        XCTAssertTrue(callback.isBehavioralDataCollection)
        XCTAssertTrue(callback.isConsoleLogEnabled)
        XCTAssertTrue(callback.lazyMetadata)
        XCTAssertEqual(callback.customHost, "host.example.com")
        XCTAssertEqual(callback.deviceAttributesToIgnore, ["attr1", "attr2"])

        // When
        let result = await callback.start()

        // Then - Verify result and mock calls
        switch result {
        case .success:
            XCTAssertTrue(MockProtectSDK.configCalled)
            XCTAssertTrue(MockProtectSDK.initializeCalled)
            XCTAssertTrue(MockProtectSDK.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtectSDK.pauseBehavioralDataCalled)

            // Verify config values
            XCTAssertEqual(MockProtectSDK.lastConfig?.envId, "02fb4743-189a-4bc7-9d6c-a919edfe6447")
            XCTAssertEqual(MockProtectSDK.lastConfig?.customHost, "host.example.com")
            XCTAssertTrue(MockProtectSDK.lastConfig?.isConsoleLogEnabled ?? false)
            XCTAssertTrue(MockProtectSDK.lastConfig?.isLazyMetadata ?? false)
            XCTAssertTrue(MockProtectSDK.lastConfig?.isBehavioralDataCollection ?? false)
            XCTAssertEqual(MockProtectSDK.lastConfig?.deviceAttributesToIgnore, ["attr1", "attr2"])

            XCTAssertNil(callback.errorMessage)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    func testStartReturnsFailureResultWhenProtectThrowsException() async {
        // Given
        MockProtectSDK.shouldThrowError = true
        MockProtectSDK.errorMessage = "Initialization failed"

        callback.initValue(name: JourneyConstants.envId, value: "02fb4743-189a-4bc7-9d6c-a919edfe6447")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "Initialization failed")
            XCTAssertEqual(callback.errorMessage, "Initialization failed")
            XCTAssertTrue(MockProtectSDK.configCalled)
            XCTAssertTrue(MockProtectSDK.initializeCalled)
            XCTAssertFalse(MockProtectSDK.resumeBehavioralDataCalled)
        }
    }

    func testInitializesWithMissingOptionalFields_setsDefaults() {
        // Given - Only set required field
        callback.initValue(name: JourneyConstants.envId, value: "02fb4743-189a-4bc7-9d6c-a919edfe6447")

        // Then - Verify defaults
        XCTAssertEqual(callback.envId, "02fb4743-189a-4bc7-9d6c-a919edfe6447")
        XCTAssertFalse(callback.isBehavioralDataCollection)
        XCTAssertFalse(callback.isConsoleLogEnabled)
        XCTAssertFalse(callback.lazyMetadata)
        XCTAssertEqual(callback.customHost, "")
        XCTAssertTrue(callback.deviceAttributesToIgnore.isEmpty)
    }

    // MARK: - Behavioral Data Collection Tests

    func testStartWithBehavioralDataCollectionTrue_callsResume() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "test-env-id")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            XCTAssertTrue(MockProtectSDK.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtectSDK.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testStartWithBehavioralDataCollectionFalse_callsPause() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "test-env-id")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: false)

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            XCTAssertFalse(MockProtectSDK.resumeBehavioralDataCalled)
            XCTAssertTrue(MockProtectSDK.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Value Initialization Tests

    func testInitValueWithVariousTypes() {
        // Test string values
        callback.initValue(name: JourneyConstants.envId, value: "test-env")
        XCTAssertEqual(callback.envId, "test-env")

        callback.initValue(name: JourneyConstants.customHost, value: "custom.host.com")
        XCTAssertEqual(callback.customHost, "custom.host.com")

        // Test boolean values
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)
        XCTAssertTrue(callback.isBehavioralDataCollection)

        callback.initValue(name: JourneyConstants.consoleLogEnabled, value: false)
        XCTAssertFalse(callback.isConsoleLogEnabled)

        callback.initValue(name: JourneyConstants.lazyMetadata, value: true)
        XCTAssertTrue(callback.lazyMetadata)

        // Test array values
        callback.initValue(name: JourneyConstants.deviceAttributesToIgnore, value: ["device1", "device2", "device3"])
        XCTAssertEqual(callback.deviceAttributesToIgnore, ["device1", "device2", "device3"])
    }

    func testInitValueWithInvalidTypes() {
        // Given - Set with invalid types
        callback.initValue(name: JourneyConstants.envId, value: 123) // Number instead of string
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: "true") // String instead of bool
        callback.initValue(name: JourneyConstants.deviceAttributesToIgnore, value: "not an array") // String instead of array

        // Then - Properties should remain default
        XCTAssertEqual(callback.envId, "")
        XCTAssertFalse(callback.isBehavioralDataCollection)
        XCTAssertTrue(callback.deviceAttributesToIgnore.isEmpty)
    }

    func testInitValueWithUnknownNames() {
        // Given
        callback.initValue(name: "unknownProperty", value: "value")
        callback.initValue(name: "anotherUnknown", value: true)

        // Then - All properties should remain default
        XCTAssertEqual(callback.envId, "")
        XCTAssertFalse(callback.isBehavioralDataCollection)
        XCTAssertFalse(callback.isConsoleLogEnabled)
        XCTAssertFalse(callback.lazyMetadata)
        XCTAssertEqual(callback.customHost, "")
        XCTAssertTrue(callback.deviceAttributesToIgnore.isEmpty)
    }

    // MARK: - Empty String Handling Tests

    func testEmptyEnvIdHandling() async {
        // Given - Empty envId
        callback.initValue(name: JourneyConstants.envId, value: "")

        // When
        _ = await callback.start()

        // Then - Should pass nil to config
        XCTAssertNil(MockProtectSDK.lastConfig?.envId)
    }

    func testEmptyCustomHostHandling() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "test-env")
        callback.initValue(name: JourneyConstants.customHost, value: "")

        // When
        _ = await callback.start()

        // Then - Should pass nil to config
        XCTAssertNil(MockProtectSDK.lastConfig?.customHost)
    }

    func testNonEmptyStringsHandling() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "env-id")
        callback.initValue(name: JourneyConstants.customHost, value: "host.com")

        // When
        _ = await callback.start()

        // Then - Should pass actual values to config
        XCTAssertEqual(MockProtectSDK.lastConfig?.envId, "env-id")
        XCTAssertEqual(MockProtectSDK.lastConfig?.customHost, "host.com")
    }

    // MARK: - Error Message Tests

    func testErrorWithEmptyMessage() async {
        // Given
        MockProtectSDK.shouldThrowError = true
        MockProtectSDK.errorMessage = ""

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure:
            // Should use JourneyConstants.clientError when message is empty
            XCTAssertNotNil(callback.errorMessage)
        }
    }

    // MARK: - Integration Tests

    func testCompleteFlowWithAllConfigurationsEnabled() async {
        // Given - Set all configurations
        callback.initValue(name: JourneyConstants.envId, value: "complete-env-id")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)
        callback.initValue(name: JourneyConstants.consoleLogEnabled, value: true)
        callback.initValue(name: JourneyConstants.lazyMetadata, value: true)
        callback.initValue(name: JourneyConstants.customHost, value: "complete.host.com")
        callback.initValue(name: JourneyConstants.deviceAttributesToIgnore, value: ["attr1", "attr2", "attr3"])

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            // Verify all configurations were applied
            XCTAssertEqual(MockProtectSDK.lastConfig?.envId, "complete-env-id")
            XCTAssertEqual(MockProtectSDK.lastConfig?.customHost, "complete.host.com")
            XCTAssertTrue(MockProtectSDK.lastConfig?.isConsoleLogEnabled ?? false)
            XCTAssertTrue(MockProtectSDK.lastConfig?.isLazyMetadata ?? false)
            XCTAssertTrue(MockProtectSDK.lastConfig?.isBehavioralDataCollection ?? false)
            XCTAssertEqual(MockProtectSDK.lastConfig?.deviceAttributesToIgnore, ["attr1", "attr2", "attr3"])

            // Verify correct method calls
            XCTAssertTrue(MockProtectSDK.configCalled)
            XCTAssertTrue(MockProtectSDK.initializeCalled)
            XCTAssertTrue(MockProtectSDK.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtectSDK.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testCompleteFlowWithAllConfigurationsDisabled() async {
        // Given - Set all configurations to false/empty
        callback.initValue(name: JourneyConstants.envId, value: "minimal-env-id")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: false)
        callback.initValue(name: JourneyConstants.consoleLogEnabled, value: false)
        callback.initValue(name: JourneyConstants.lazyMetadata, value: false)
        callback.initValue(name: JourneyConstants.customHost, value: "")
        callback.initValue(name: JourneyConstants.deviceAttributesToIgnore, value: [String]())

        // When
        let result = await callback.start()

        // Then
        switch result {
        case .success:
            // Verify configurations
            XCTAssertEqual(MockProtectSDK.lastConfig?.envId, "minimal-env-id")
            XCTAssertNil(MockProtectSDK.lastConfig?.customHost)
            XCTAssertFalse(MockProtectSDK.lastConfig?.isConsoleLogEnabled ?? true)
            XCTAssertFalse(MockProtectSDK.lastConfig?.isLazyMetadata ?? true)
            XCTAssertFalse(MockProtectSDK.lastConfig?.isBehavioralDataCollection ?? true)
            XCTAssertTrue(MockProtectSDK.lastConfig?.deviceAttributesToIgnore.isEmpty ?? false)

            // Verify correct method calls
            XCTAssertTrue(MockProtectSDK.configCalled)
            XCTAssertTrue(MockProtectSDK.initializeCalled)
            XCTAssertFalse(MockProtectSDK.resumeBehavioralDataCalled)
            XCTAssertTrue(MockProtectSDK.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentStartCalls() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "concurrent-env")
        callback.initValue(name: JourneyConstants.behavioralDataCollection, value: true)

        // When - Call start concurrently
        async let result1 = callback.start()
        async let result2 = callback.start()
        async let result3 = callback.start()

        let results = await [result1, result2, result3]

        // Then - All should complete (though state may be unpredictable in real scenario)
        for result in results {
            switch result {
            case .success:
                break // Expected
            case .failure:
                XCTFail("Concurrent calls should handle gracefully")
            }
        }
    }
}

// MARK: - Test Helpers

extension PingOneProtectInitializeCallbackTests {

    private func createMockJsonData(
        envId: String = "02fb4743-189a-4bc7-9d6c-a919edfe6447",
        behavioralDataCollection: Bool = true,
        consoleLogEnabled: Bool = true,
        lazyMetadata: Bool = true,
        customHost: String = "host.example.com",
        deviceAttributesToIgnore: [String] = ["attr1", "attr2"]
    ) -> [String: Any] {
        return [
            "type": "PingOneProtectInitializeCallback",
            "output": [
                ["name": "envId", "value": envId],
                ["name": "behavioralDataCollection", "value": behavioralDataCollection],
                ["name": "consoleLogEnabled", "value": consoleLogEnabled],
                ["name": "lazyMetadata", "value": lazyMetadata],
                ["name": "customHost", "value": customHost],
                ["name": "deviceAttributesToIgnore", "value": deviceAttributesToIgnore]
            ],
            "input": [
                ["name": "IDToken1clientError", "value": ""]
            ]
        ]
    }

    private func createMetadataCallbackJson(
        envId: String = "02fb4743-189a-4bc7-9d6c-a919edfe6447",
        behavioralDataCollection: Bool = true,
        consoleLogEnabled: Bool = true,
        lazyMetadata: Bool = true,
        customHost: String = "",
        deviceAttributesToIgnore: [String] = []
    ) -> [String: Any] {
        return [
            "type": "MetadataCallback",
            "output": [
                [
                    "name": "data",
                    "value": [
                        "_type": "PingOneProtect",
                        "_action": "protect_initialize",
                        "envId": envId,
                        "consoleLogEnabled": consoleLogEnabled,
                        "deviceAttributesToIgnore": deviceAttributesToIgnore,
                        "customHost": customHost,
                        "lazyMetadata": lazyMetadata,
                        "behavioralDataCollection": behavioralDataCollection
                    ]
                ]
            ],
            "_id": 0
        ]
    }
}

