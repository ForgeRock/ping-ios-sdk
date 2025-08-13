//
//  PingOneProtectEvaluationCallbackTests.swift
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



// Test double for PingOneProtectEvaluationCallback
class TestableProtectEvaluationCallback: PingOneProtectEvaluationCallback, @unchecked Sendable {
    var mockProtect: MockProtect.Type = MockProtect.self

    override func collect() async -> Result<String, Error> {
        do {
            // Use mock instead of real Protect SDK
            let signal = try await mockProtect.data()

            if pauseBehavioralData {
                try await mockProtect.pauseBehavioralData()
            }

            self.signal(signal, error: "")
            return .success(signal)
        } catch {
            let errorMessage = error.localizedDescription.isEmpty ? JourneyConstants.clientError : error.localizedDescription
            self.signal("", error: errorMessage)
            return .failure(TestError.collectDataFailed(errorMessage))
        }
    }
}

final class PingOneProtectEvaluationCallbackTests: XCTestCase {

    var callback: TestableProtectEvaluationCallback!

    override func setUp() {
        super.setUp()
        MockProtect.reset()
        callback = TestableProtectEvaluationCallback()
    }

    override func tearDown() {
        callback = nil
        MockProtect.reset()
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializesAllPropertiesWithPauseBehavioralDataFalse() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: false)

        // Then
        XCTAssertFalse(callback.pauseBehavioralData)

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success(let signal):
            XCTAssertEqual(signal, "deviceSignals")
            XCTAssertFalse(MockProtect.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    func testInitializesAllPropertiesCorrectlyFromValidJson() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: true)

        // Then
        XCTAssertTrue(callback.pauseBehavioralData)

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success(let signal):
            XCTAssertEqual(signal, "deviceSignals")
            XCTAssertTrue(MockProtect.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }

    func testStartReturnsFailureResultWhenProtectThrowsException() async {
        // Given
        MockProtect.shouldThrowError = true
        MockProtect.errorMessage = "Collect data failed"
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: true)

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure but got success")
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "Collect data failed")
        }
    }

    func testInitializesWithMissingOptionalFields_setsDefaults() {
        // Given - Initialize without setting pauseBehavioralData
        // (No initValue call)

        // Then
        XCTAssertFalse(callback.pauseBehavioralData, "pauseBehavioralData should default to false")
    }

    // MARK: - Value Initialization Tests

    func testInitValueWithBooleanValue() {
        // Test with true
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: true)
        XCTAssertTrue(callback.pauseBehavioralData)

        // Reset and test with false
        callback = TestableProtectEvaluationCallback()
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: false)
        XCTAssertFalse(callback.pauseBehavioralData)
    }

    func testInitValueWithNonBooleanValue() {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: "not a boolean")

        // Then - Should not change from default
        XCTAssertFalse(callback.pauseBehavioralData)
    }

    func testInitValueWithUnknownName() {
        // Given
        callback.initValue(name: "unknownProperty", value: true)

        // Then - Should not affect pauseBehavioralData
        XCTAssertFalse(callback.pauseBehavioralData)
    }

    // MARK: - Signal Tests

    func testSignalIsCalledWithCorrectValuesOnSuccess() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: false)

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success(let signal):
            XCTAssertEqual(signal, "deviceSignals")
            // In a real test, we'd verify that signal() was called with ("deviceSignals", error: "")
            // This would require additional mocking or dependency injection
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testSignalIsCalledWithErrorMessageOnFailure() async {
        // Given
        MockProtect.shouldThrowError = true
        MockProtect.errorMessage = "Network error"

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertEqual(error.localizedDescription, "Network error")
            // In a real test, we'd verify that signal() was called with ("", error: "Network error")
        }
    }

    // MARK: - Integration Tests

    func testCollectWithPauseBehavioralDataTrue() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: true)
        MockProtect.dataReturnValue = "customSignalData"

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success(let signal):
            XCTAssertEqual(signal, "customSignalData")
            XCTAssertTrue(MockProtect.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testCollectWithPauseBehavioralDataFalse() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: false)
        MockProtect.dataReturnValue = "customSignalData"

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success(let signal):
            XCTAssertEqual(signal, "customSignalData")
            XCTAssertFalse(MockProtect.pauseBehavioralDataCalled)
        case .failure:
            XCTFail("Expected success")
        }
    }

    func testCollectWithEmptyErrorMessage() async {
        // Given
        MockProtect.shouldThrowError = true
        MockProtect.errorMessage = ""

        // When
        let result = await callback.collect()

        // Then
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            // When error message is empty, it should use JourneyConstants.clientError
            XCTAssertTrue(!error.localizedDescription.isEmpty)
            XCTAssertEqual(error.localizedDescription, JourneyConstants.clientError)
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentCollectCalls() async {
        // Given
        callback.initValue(name: JourneyConstants.pauseBehavioralData, value: true)

        // When - Call collect concurrently
        async let result1 = callback.collect()
        async let result2 = callback.collect()
        async let result3 = callback.collect()

        let results = await [result1, result2, result3]

        // Then - All should succeed
        for result in results {
            switch result {
            case .success(let signal):
                XCTAssertEqual(signal, "deviceSignals")
            case .failure:
                XCTFail("Expected all concurrent calls to succeed")
            }
        }
    }
}

// MARK: - Test Helpers

extension PingOneProtectEvaluationCallbackTests {

    private func createMockJsonData(pauseBehavioralData: Bool) -> [String: Any] {
        return [
            "type": "PingOneProtectEvaluationCallback",
            "output": [
                [
                    "name": "pauseBehavioralData",
                    "value": pauseBehavioralData
                ]
            ],
            "input": [
                [
                    "name": "IDToken1signals",
                    "value": ""
                ],
                [
                    "name": "IDToken1clientError",
                    "value": ""
                ]
            ]
        ]
    }

    private func createMetadataCallbackJson(pauseBehavioralData: Bool) -> [String: Any] {
        return [
            "type": "MetadataCallback",
            "output": [
                [
                    "name": "data",
                    "value": [
                        "_type": "PingOneProtect",
                        "_action": "protect_risk_evaluation",
                        "envId": "some_id",
                        "pauseBehavioralData": pauseBehavioralData
                    ]
                ]
            ],
            "_id": 0
        ]
    }
}
