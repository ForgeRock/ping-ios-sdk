//
//  OathConfigurationTests.swift
//  PingOathTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingLogger
import PingMfaCommons
@testable import PingOath

final class OathConfigurationTests: XCTestCase {

    // MARK: - Default Initialization Tests

    func testDefaultInitialization() {
        let config = OathConfiguration()

        XCTAssertNil(config.storage)
        XCTAssertNil(config.policyEvaluator)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 15.0)
        XCTAssertFalse(config.enableCredentialCache)
        XCTAssertNotNil(config.logger)
    }

    func testDefaultValuesAreSecure() {
        let config = OathConfiguration()

        // Security defaults should be enabled
        XCTAssertTrue(config.encryptionEnabled, "Encryption should be enabled by default for security")
        XCTAssertFalse(config.enableCredentialCache, "Credential caching should be disabled by default for security")
    }

    // MARK: - Factory Method Tests

    func testBuildFactoryMethodWithNoConfiguration() {
        let config = OathConfiguration.build { _ in }

        // Should have default values
        XCTAssertNil(config.storage)
        XCTAssertNil(config.policyEvaluator)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 15.0)
        XCTAssertFalse(config.enableCredentialCache)
        XCTAssertNotNil(config.logger)
    }

    func testBuildFactoryMethodWithFullConfiguration() {
        let testLogger = TestLogger()
        let testStorage = OathInMemoryStorage()
        let testPolicyEvaluator = MfaPolicyEvaluator.create()

        let config = OathConfiguration.build { config in
            config.storage = testStorage
            config.policyEvaluator = testPolicyEvaluator
            config.encryptionEnabled = false
            config.timeoutMs = 30.0
            config.enableCredentialCache = true
            config.logger = testLogger
        }

        XCTAssertNotNil(config.storage)
        XCTAssertTrue(config.storage is OathInMemoryStorage)
        XCTAssertNotNil(config.policyEvaluator)
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 30.0)
        XCTAssertTrue(config.enableCredentialCache)
        XCTAssertTrue(config.logger is TestLogger)
    }

    func testBuildFactoryMethodWithPartialConfiguration() {
        let testStorage = OathInMemoryStorage()

        let config = OathConfiguration.build { config in
            config.storage = testStorage
            config.timeoutMs = 25.0
        }

        // Configured values
        XCTAssertNotNil(config.storage)
        XCTAssertTrue(config.storage is OathInMemoryStorage)
        XCTAssertEqual(config.timeoutMs, 25.0)

        // Default values should remain
        XCTAssertNil(config.policyEvaluator)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertFalse(config.enableCredentialCache)
        XCTAssertNotNil(config.logger)
    }

    // MARK: - Property Modification Tests

    func testStoragePropertyModification() {
        let config = OathConfiguration()
        XCTAssertNil(config.storage)

        let testStorage = OathInMemoryStorage()
        config.storage = testStorage

        XCTAssertNotNil(config.storage)
        XCTAssertTrue(config.storage is OathInMemoryStorage)

        // Can be set back to nil
        config.storage = nil
        XCTAssertNil(config.storage)
    }

    func testPolicyEvaluatorPropertyModification() {
        let config = OathConfiguration()
        XCTAssertNil(config.policyEvaluator)

        let testPolicyEvaluator = MfaPolicyEvaluator.create()
        config.policyEvaluator = testPolicyEvaluator

        XCTAssertNotNil(config.policyEvaluator)

        // Can be set back to nil
        config.policyEvaluator = nil
        XCTAssertNil(config.policyEvaluator)
    }

    func testEncryptionEnabledPropertyModification() {
        let config = OathConfiguration()
        XCTAssertTrue(config.encryptionEnabled)

        config.encryptionEnabled = false
        XCTAssertFalse(config.encryptionEnabled)

        config.encryptionEnabled = true
        XCTAssertTrue(config.encryptionEnabled)
    }

    func testTimeoutPropertyModification() {
        let config = OathConfiguration()
        XCTAssertEqual(config.timeoutMs, 15.0)

        config.timeoutMs = 10.0
        XCTAssertEqual(config.timeoutMs, 10.0)

        config.timeoutMs = 60.0
        XCTAssertEqual(config.timeoutMs, 60.0)

        config.timeoutMs = 0.5
        XCTAssertEqual(config.timeoutMs, 0.5)
    }

    func testCredentialCachePropertyModification() {
        let config = OathConfiguration()
        XCTAssertFalse(config.enableCredentialCache)

        config.enableCredentialCache = true
        XCTAssertTrue(config.enableCredentialCache)

        config.enableCredentialCache = false
        XCTAssertFalse(config.enableCredentialCache)
    }

    func testLoggerPropertyModification() {
        let config = OathConfiguration()
        let originalLogger = config.logger

        let testLogger = TestLogger()
        config.logger = testLogger

        XCTAssertTrue(config.logger is TestLogger)
        // Test that the logger was actually changed by checking the concrete type
        XCTAssertFalse(config.logger is TestLogger && originalLogger is TestLogger,
                      "Logger should be different from original")

        // Can be set back to original
        config.logger = originalLogger
        XCTAssertFalse(config.logger is TestLogger, "Logger should be reverted to original type")
    }

    // MARK: - Edge Cases and Boundary Tests

    func testNegativeTimeoutValue() {
        let config = OathConfiguration()

        config.timeoutMs = -5.0
        XCTAssertEqual(config.timeoutMs, -5.0)
        // Note: The configuration doesn't validate the timeout value,
        // that's left to the consuming code
    }

    func testZeroTimeoutValue() {
        let config = OathConfiguration()

        config.timeoutMs = 0.0
        XCTAssertEqual(config.timeoutMs, 0.0)
    }

    func testVeryLargeTimeoutValue() {
        let config = OathConfiguration()

        config.timeoutMs = Double.greatestFiniteMagnitude
        XCTAssertEqual(config.timeoutMs, Double.greatestFiniteMagnitude)
    }

    func testVerySmallTimeoutValue() {
        let config = OathConfiguration()

        config.timeoutMs = Double.leastNormalMagnitude
        XCTAssertEqual(config.timeoutMs, Double.leastNormalMagnitude)
    }

    // MARK: - Multiple Configuration Changes Tests

    func testMultipleConfigurationChanges() {
        let config = OathConfiguration.build { config in
            config.encryptionEnabled = false
            config.timeoutMs = 10.0
        }

        // Verify initial state
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 10.0)

        // Make additional changes
        config.enableCredentialCache = true
        config.timeoutMs = 20.0
        let testStorage = OathInMemoryStorage()
        config.storage = testStorage

        // Verify all changes
        XCTAssertFalse(config.encryptionEnabled) // Should remain unchanged
        XCTAssertEqual(config.timeoutMs, 20.0)   // Should be updated
        XCTAssertTrue(config.enableCredentialCache) // Should be updated
        XCTAssertNotNil(config.storage)          // Should be updated
        XCTAssertTrue(config.storage is OathInMemoryStorage)
    }

    func testConfigurationIsolation() {
        let testStorage1 = OathInMemoryStorage()
        let testStorage2 = OathInMemoryStorage()

        let config1 = OathConfiguration.build { config in
            config.storage = testStorage1
            config.timeoutMs = 10.0
        }

        let config2 = OathConfiguration.build { config in
            config.storage = testStorage2
            config.timeoutMs = 20.0
        }

        // Configurations should be independent
        XCTAssertEqual(config1.timeoutMs, 10.0)
        XCTAssertEqual(config2.timeoutMs, 20.0)
        XCTAssertTrue(config1.storage is OathInMemoryStorage)
        XCTAssertTrue(config2.storage is OathInMemoryStorage)
        XCTAssertNotIdentical(config1.storage as AnyObject, config2.storage as AnyObject)
    }

    // MARK: - Sendable Compliance Tests

    func testSendableCompliance() {
        // This test verifies that OathConfiguration can be safely passed between actors
        let config = OathConfiguration()

        // This should compile without warnings if Sendable is properly implemented
        Task {
            let _ = config.timeoutMs
            let _ = config.encryptionEnabled
        }
    }

    // MARK: - Memory Management Tests

    func testMemoryManagement() {
        weak var weakConfig: OathConfiguration?
        weak var weakStorage: OathInMemoryStorage?

        autoreleasepool {
            let storage = OathInMemoryStorage()
            let config = OathConfiguration.build { config in
                config.storage = storage
            }

            weakConfig = config
            weakStorage = storage
        }

        // Both should be deallocated when out of scope
        XCTAssertNil(weakConfig, "Configuration should be deallocated")
        XCTAssertNil(weakStorage, "Storage should be deallocated")
    }

    func testStorageRetainCycle() {
        weak var weakConfig: OathConfiguration?
        weak var weakStorage: OathInMemoryStorage?

        autoreleasepool {
            let config = OathConfiguration()
            let storage = OathInMemoryStorage()

            config.storage = storage
            // Don't create a retain cycle by having storage hold config

            weakConfig = config
            weakStorage = storage
        }

        // Both should be deallocated
        XCTAssertNil(weakConfig, "Configuration should be deallocated")
        XCTAssertNil(weakStorage, "Storage should be deallocated")
    }

    // MARK: - Configuration Validation Tests

    func testValidConfigurationScenarios() {
        // Test commonly used valid configurations

        // Minimal configuration
        let minimalConfig = OathConfiguration.build { _ in }
        XCTAssertNotNil(minimalConfig)

        // Production-like configuration
        let productionConfig = OathConfiguration.build { config in
            config.storage = OathInMemoryStorage()
            config.encryptionEnabled = true
            config.enableCredentialCache = false
            config.timeoutMs = 30.0
        }
        XCTAssertNotNil(productionConfig)
        XCTAssertTrue(productionConfig.encryptionEnabled)
        XCTAssertFalse(productionConfig.enableCredentialCache)

        // Development configuration
        let devConfig = OathConfiguration.build { config in
            config.enableCredentialCache = true
            config.timeoutMs = 5.0
            config.logger = TestLogger()
        }
        XCTAssertNotNil(devConfig)
        XCTAssertTrue(devConfig.enableCredentialCache)
    }
}
