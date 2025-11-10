//
//  ProtectTests.swift
//  ProtectTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect
@testable import PingDavinci
@testable import PingOneSignals

final class ProtectTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        // Reset SDK state before each test
        await Protect.reset()
    }

    override func tearDown() async throws {
        // Clean up after each test
        await Protect.reset()
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func test01_InitializeThrowsErrorIfNotConfigured() async {
        do {
            try await Protect.initialize()
            XCTFail("Should have thrown an error")
        } catch let error as ProtectError {
            XCTAssertEqual(error.message, "Protect SDK not configured. Call config() first.")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test02_ConfigSetsAllProtectConfigPropertiesCorrectly() async {
        // When
        await Protect.config {
            $0.envId = "env123"
            $0.deviceAttributesToIgnore = ["attr1", "attr2"]
            $0.customHost = "custom.host"
            $0.isConsoleLogEnabled = true
            $0.isLazyMetadata = true
            $0.isBehavioralDataCollection = false
        }

        // Then
        let config = await Protect.protectConfig
        guard let config = config else {
            XCTFail("Protect config should not be nil")
            return
        }
        XCTAssertEqual(config.envId, "env123")
        XCTAssertEqual(config.deviceAttributesToIgnore, ["attr1", "attr2"])
        XCTAssertEqual(config.customHost, "custom.host")
        XCTAssertTrue(config.isConsoleLogEnabled)
        XCTAssertTrue(config.isLazyMetadata)
        XCTAssertFalse(config.isBehavioralDataCollection)
    }

    func test03_ConfigWithEmptyConfiguration() async {
        // When
        await Protect.config { _ in  }

        // Then
        let config = await Protect.protectConfig
        guard let config = config else {
            XCTFail("Protect config should not be nil")
            return
        }
        XCTAssertNil(config.envId)
        XCTAssertEqual(config.deviceAttributesToIgnore, [])
        XCTAssertNil(config.customHost)
        XCTAssertFalse(config.isConsoleLogEnabled)
        XCTAssertFalse(config.isLazyMetadata)
        XCTAssertTrue(config.isBehavioralDataCollection)
    }

    // MARK: - Initialization Tests

    func test04_InitDoesNotReinitializeIfAlreadyInitialized() async throws {
        await Protect.config {
            $0.envId = "env1"
        }

        try await Protect.initialize()
        let isInitialized = await Protect.isInitialized
        let envId = await Protect.protectConfig?.envId

        XCTAssertTrue(isInitialized)
        XCTAssertEqual(envId, "env1")

        // Second initialization should not throw
        try await Protect.initialize()
        let stillInitialized = await Protect.isInitialized
        XCTAssertTrue(stillInitialized)
    }

    func test05_InitializationWithValidConfig() async throws {
        // Given
        await Protect.config {
            $0.envId = "test-env-id"
            $0.isConsoleLogEnabled = true
        }

        // When
        try await Protect.initialize()

        // Then
        let isInitialized = await Protect.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - Data Retrieval Tests

    func test07_DataReturnsSignalsAfterInitialization() async throws {
        // Given
        await Protect.config {
            $0.envId = "test-env-id"
        }
        try await Protect.initialize()

        // When
        let data = try await Protect.data()

        // Then
        XCTAssertNotNil(data)
        XCTAssertFalse(data.isEmpty)
    }

    // MARK: - Behavioral Data Control Tests

    func test10_PauseAndResumeBehavioralDataAfterInitialization() async throws {
        // Given
        await Protect.config {
            $0.envId = "test-env-id"
            $0.isBehavioralDataCollection = true
        }
        try await Protect.initialize()

        // When & Then - Should not throw
        try Protect.pauseBehavioralData()
        try Protect.resumeBehavioralData()
    }

    // MARK: - Thread Safety Tests

    func test11_ConcurrentConfigurationCalls() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<5 {
                group.addTask {
                    await Protect.config {
                        $0.envId = "env\(index)"
                        $0.isConsoleLogEnabled = index % 2 == 0
                    }
                }
            }
        }

        let config = await Protect.protectConfig
        XCTAssertNotNil(config)
    }

    func test12_ConcurrentInitializationCalls() async throws {
        // Given
        await Protect.config {
            $0.envId = "test-env-id"
        }

        // When - Multiple concurrent initialization calls
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        try await Protect.initialize()
                    } catch {
                        XCTFail("Initialization should not fail in concurrent calls: \(error)")
                    }
                }
            }
        }

        // Then
        let isInitialized = await Protect.isInitialized
        XCTAssertTrue(isInitialized)
    }

    // MARK: - Edge Cases

    func test13_ResetFunctionality() async {
        // Given
        await Protect.config {
            $0.envId = "test"
        }

        // When
        await Protect.reset()

        // Then
        let isInitialized = await Protect.isInitialized
        let config = await Protect.protectConfig
        XCTAssertFalse(isInitialized)
        XCTAssertNil(config)
    }

    func test14_MultipleConfigurationCalls() async {
        // First configuration
        await Protect.config {
            $0.envId = "first"
            $0.isConsoleLogEnabled = true
        }

        // Second configuration should override
        await Protect.config {
            $0.envId = "second"
            $0.isConsoleLogEnabled = false
        }

        let config = await Protect.protectConfig
        guard let config = config else {
            XCTFail("Config should not be nil")
            return
        }

        XCTAssertEqual(config.envId, "second")
        XCTAssertFalse(config.isConsoleLogEnabled)
    }

    // MARK: - Error Message Tests
}
