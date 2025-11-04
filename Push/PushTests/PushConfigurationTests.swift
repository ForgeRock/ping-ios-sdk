//
//  PushConfigurationTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class PushConfigurationTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testDefaultInitialization() {
        let config = PushConfiguration()
        
        XCTAssertNil(config.storage)
        XCTAssertNil(config.policyEvaluator)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 15000)
        XCTAssertFalse(config.enableCredentialCache)
        XCTAssertNil(config.logger)
        XCTAssertTrue(config.customPushHandlers.isEmpty)
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .countBased)
        XCTAssertEqual(config.notificationCleanupConfig.maxStoredNotifications, 100)
    }
    
    // MARK: - Builder Pattern Tests
    
    func testBuildWithDefaultConfiguration() {
        let config = PushConfiguration.build { _ in }
        
        XCTAssertNil(config.storage)
        XCTAssertNil(config.policyEvaluator)
        XCTAssertTrue(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 15000)
        XCTAssertFalse(config.enableCredentialCache)
        XCTAssertNil(config.logger)
        XCTAssertTrue(config.customPushHandlers.isEmpty)
    }
    
    func testBuildWithCustomConfiguration() {
        let config = PushConfiguration.build { config in
            config.encryptionEnabled = false
            config.timeoutMs = 30000
            config.enableCredentialCache = true
        }
        
        XCTAssertFalse(config.encryptionEnabled)
        XCTAssertEqual(config.timeoutMs, 30000)
        XCTAssertTrue(config.enableCredentialCache)
    }
    
    func testBuildWithCustomCleanupConfig() {
        let config = PushConfiguration.build { config in
            config.notificationCleanupConfig = .ageBased(maxAgeDays: 7)
        }
        
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .ageBased)
        XCTAssertEqual(config.notificationCleanupConfig.maxNotificationAgeDays, 7)
    }
    
    func testBuildWithCustomHandlers() {
        let customHandler = "CustomHandler"
        
        let config = PushConfiguration.build { config in
            config.customPushHandlers = ["CUSTOM": customHandler]
        }
        
        XCTAssertEqual(config.customPushHandlers.count, 1)
        XCTAssertNotNil(config.customPushHandlers["CUSTOM"])
    }
    
    // MARK: - Property Modification Tests
    
    func testModifyEncryptionEnabled() {
        var config = PushConfiguration()
        XCTAssertTrue(config.encryptionEnabled)
        
        config.encryptionEnabled = false
        XCTAssertFalse(config.encryptionEnabled)
        
        config.encryptionEnabled = true
        XCTAssertTrue(config.encryptionEnabled)
    }
    
    func testModifyTimeoutMs() {
        var config = PushConfiguration()
        XCTAssertEqual(config.timeoutMs, 15000)
        
        config.timeoutMs = 5000
        XCTAssertEqual(config.timeoutMs, 5000)
        
        config.timeoutMs = 60000
        XCTAssertEqual(config.timeoutMs, 60000)
    }
    
    func testModifyEnableCredentialCache() {
        var config = PushConfiguration()
        XCTAssertFalse(config.enableCredentialCache)
        
        config.enableCredentialCache = true
        XCTAssertTrue(config.enableCredentialCache)
        
        config.enableCredentialCache = false
        XCTAssertFalse(config.enableCredentialCache)
    }
    
    func testModifyNotificationCleanupConfig() {
        var config = PushConfiguration()
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .countBased)
        
        config.notificationCleanupConfig = .none()
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .none)
        
        config.notificationCleanupConfig = .hybrid(maxNotifications: 25, maxAgeDays: 5)
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .hybrid)
        XCTAssertEqual(config.notificationCleanupConfig.maxStoredNotifications, 25)
        XCTAssertEqual(config.notificationCleanupConfig.maxNotificationAgeDays, 5)
    }
    
    // MARK: - Complex Configuration Tests
    
    func testSecurityFocusedConfiguration() {
        let config = PushConfiguration.build { config in
            config.encryptionEnabled = true
            config.enableCredentialCache = false
            config.notificationCleanupConfig = .ageBased(maxAgeDays: 7)
        }
        
        // Verify security-focused settings
        XCTAssertTrue(config.encryptionEnabled, "Encryption should be enabled")
        XCTAssertFalse(config.enableCredentialCache, "Credential caching should be disabled")
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .ageBased)
        XCTAssertEqual(config.notificationCleanupConfig.maxNotificationAgeDays, 7)
    }
    
    func testPerformanceFocusedConfiguration() {
        let config = PushConfiguration.build { config in
            config.enableCredentialCache = true
            config.timeoutMs = 5000
            config.notificationCleanupConfig = .countBased(maxNotifications: 50)
        }
        
        // Verify performance-focused settings
        XCTAssertTrue(config.enableCredentialCache, "Credential caching should be enabled")
        XCTAssertEqual(config.timeoutMs, 5000, "Timeout should be reduced")
        XCTAssertEqual(config.notificationCleanupConfig.maxStoredNotifications, 50)
    }
    
    func testDevelopmentConfiguration() {
        let config = PushConfiguration.build { config in
            config.timeoutMs = 60000  // Longer timeout for debugging
            config.notificationCleanupConfig = .none()  // Keep all notifications
        }
        
        // Verify development-friendly settings
        XCTAssertEqual(config.timeoutMs, 60000)
        XCTAssertEqual(config.notificationCleanupConfig.cleanupMode, .none)
    }
    
    // MARK: - Edge Case Tests
    
    func testMultipleBuilderCalls() {
        let config1 = PushConfiguration.build { config in
            config.timeoutMs = 10000
        }
        
        let config2 = PushConfiguration.build { config in
            config.timeoutMs = 20000
        }
        
        XCTAssertEqual(config1.timeoutMs, 10000)
        XCTAssertEqual(config2.timeoutMs, 20000)
    }
    
    func testEmptyBuilderBlock() {
        let config1 = PushConfiguration.build { _ in }
        let config2 = PushConfiguration()
        
        XCTAssertEqual(config1.timeoutMs, config2.timeoutMs)
        XCTAssertEqual(config1.encryptionEnabled, config2.encryptionEnabled)
        XCTAssertEqual(config1.enableCredentialCache, config2.enableCredentialCache)
    }
    
    // MARK: - Sendable Compliance Tests
    
    func testSendableCompliance() async {
        let config = PushConfiguration.build { config in
            config.timeoutMs = 20000
            config.encryptionEnabled = false
        }
        
        await Task {
            XCTAssertEqual(config.timeoutMs, 20000)
            XCTAssertFalse(config.encryptionEnabled)
        }.value
    }
}
