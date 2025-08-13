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



// Test double for PingOneProtectInitializeCallback
class TestableProtectInitializeCallback: PingOneProtectInitializeCallback, @unchecked Sendable {
    var mockProtect: MockProtect.Type = MockProtect.self
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
        MockProtect.reset()
        callback = TestableProtectInitializeCallback()
    }

    override func tearDown() {
        callback = nil
        MockProtect.reset()
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
            XCTAssertTrue(MockProtect.configCalled)
            XCTAssertTrue(MockProtect.initializeCalled)
            XCTAssertTrue(MockProtect.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtect.pauseBehavioralDataCalled)

            // Verify config values
            XCTAssertEqual(MockProtect.lastConfig?.envId, "02fb4743-189a-4bc7-9d6c-a919edfe6447")
            XCTAssertEqual(MockProtect.lastConfig?.customHost, "host.example.com")
            XCTAssertTrue(MockProtect.lastConfig?.isConsoleLogEnabled ?? false)
            XCTAssertTrue(MockProtect.lastConfig?.isLazyMetadata ?? false)
            XCTAssertTrue(MockProtect.lastConfig?.isBehavioralDataCollection ?? false)
            XCTAssertEqual(MockProtect.lastConfig?.deviceAttributesToIgnore, ["attr1", "attr2"])

            XCTAssertNil(callback.errorMessage)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    func testStartReturnsFailureResultWhenProtectThrowsException() async {
        // Given
        MockProtect.shouldThrowError = true
        MockProtect.errorMessage = "Initialization failed"

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
            XCTAssertTrue(MockProtect.configCalled)
            XCTAssertTrue(MockProtect.initializeCalled)
            XCTAssertFalse(MockProtect.resumeBehavioralDataCalled)
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
            XCTAssertTrue(MockProtect.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtect.pauseBehavioralDataCalled)
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
            XCTAssertFalse(MockProtect.resumeBehavioralDataCalled)
            XCTAssertTrue(MockProtect.pauseBehavioralDataCalled)
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
        XCTAssertNil(MockProtect.lastConfig?.envId)
    }

    func testEmptyCustomHostHandling() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "test-env")
        callback.initValue(name: JourneyConstants.customHost, value: "")

        // When
        _ = await callback.start()

        // Then - Should pass nil to config
        XCTAssertNil(MockProtect.lastConfig?.customHost)
    }

    func testNonEmptyStringsHandling() async {
        // Given
        callback.initValue(name: JourneyConstants.envId, value: "env-id")
        callback.initValue(name: JourneyConstants.customHost, value: "host.com")

        // When
        _ = await callback.start()

        // Then - Should pass actual values to config
        XCTAssertEqual(MockProtect.lastConfig?.envId, "env-id")
        XCTAssertEqual(MockProtect.lastConfig?.customHost, "host.com")
    }

    // MARK: - Error Message Tests

    func testErrorWithEmptyMessage() async {
        // Given
        MockProtect.shouldThrowError = true
        MockProtect.errorMessage = ""

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
            XCTAssertEqual(MockProtect.lastConfig?.envId, "complete-env-id")
            XCTAssertEqual(MockProtect.lastConfig?.customHost, "complete.host.com")
            XCTAssertTrue(MockProtect.lastConfig?.isConsoleLogEnabled ?? false)
            XCTAssertTrue(MockProtect.lastConfig?.isLazyMetadata ?? false)
            XCTAssertTrue(MockProtect.lastConfig?.isBehavioralDataCollection ?? false)
            XCTAssertEqual(MockProtect.lastConfig?.deviceAttributesToIgnore, ["attr1", "attr2", "attr3"])

            // Verify correct method calls
            XCTAssertTrue(MockProtect.configCalled)
            XCTAssertTrue(MockProtect.initializeCalled)
            XCTAssertTrue(MockProtect.resumeBehavioralDataCalled)
            XCTAssertFalse(MockProtect.pauseBehavioralDataCalled)
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
            XCTAssertEqual(MockProtect.lastConfig?.envId, "minimal-env-id")
            XCTAssertNil(MockProtect.lastConfig?.customHost)
            XCTAssertFalse(MockProtect.lastConfig?.isConsoleLogEnabled ?? true)
            XCTAssertFalse(MockProtect.lastConfig?.isLazyMetadata ?? true)
            XCTAssertFalse(MockProtect.lastConfig?.isBehavioralDataCollection ?? true)
            XCTAssertTrue(MockProtect.lastConfig?.deviceAttributesToIgnore.isEmpty ?? false)

            // Verify correct method calls
            XCTAssertTrue(MockProtect.configCalled)
            XCTAssertTrue(MockProtect.initializeCalled)
            XCTAssertFalse(MockProtect.resumeBehavioralDataCalled)
            XCTAssertTrue(MockProtect.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentStartCalls() async {
        callback.initValue(name: JourneyConstants.envId, value: "concurrent-env")

        let concurrentCount = 100 // <-- Maybe we can change that to a smaller number
        let tasks = (0..<concurrentCount).map { _ in
            Task { await callback.start() }
        }

        let results = await withTaskGroup(of: Result<Void, Error>.self) { group in
            for task in tasks {
                group.addTask { await task.value }
            }

            var results: [Result<Void, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }

        // Verify all results and check for race conditions
        XCTAssertEqual(results.count, concurrentCount)
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

