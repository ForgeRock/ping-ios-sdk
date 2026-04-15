//
//  NotificationCleanupConfigTests.swift
//  PingPushTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingPush

final class NotificationCleanupConfigTests: XCTestCase {
    
    // MARK: - Default Values Tests
    
    func testDefaultInitialization() {
        let config = NotificationCleanupConfig()
        
        XCTAssertEqual(config.cleanupMode, .countBased)
        XCTAssertEqual(config.maxStoredNotifications, 100)
        XCTAssertEqual(config.maxNotificationAgeDays, 30)
    }
    
    func testDefaultFactoryMethod() {
        let config = NotificationCleanupConfig.default()
        
        XCTAssertEqual(config.cleanupMode, .countBased)
        XCTAssertEqual(config.maxStoredNotifications, 100)
        XCTAssertEqual(config.maxNotificationAgeDays, 30)
    }
    
    // MARK: - Custom Initialization Tests
    
    func testCustomInitialization() {
        let config = NotificationCleanupConfig(
            cleanupMode: .hybrid,
            maxStoredNotifications: 50,
            maxNotificationAgeDays: 14
        )
        
        XCTAssertEqual(config.cleanupMode, .hybrid)
        XCTAssertEqual(config.maxStoredNotifications, 50)
        XCTAssertEqual(config.maxNotificationAgeDays, 14)
    }
    
    func testNegativeValuesAreClampedToOne() {
        let config = NotificationCleanupConfig(
            cleanupMode: .hybrid,
            maxStoredNotifications: -10,
            maxNotificationAgeDays: -5
        )
        
        XCTAssertEqual(config.maxStoredNotifications, 1)
        XCTAssertEqual(config.maxNotificationAgeDays, 1)
    }
    
    func testZeroValuesAreClampedToOne() {
        let config = NotificationCleanupConfig(
            cleanupMode: .countBased,
            maxStoredNotifications: 0,
            maxNotificationAgeDays: 0
        )
        
        XCTAssertEqual(config.maxStoredNotifications, 1)
        XCTAssertEqual(config.maxNotificationAgeDays, 1)
    }
    
    // MARK: - Factory Methods Tests
    
    func testNoneFactoryMethod() {
        let config = NotificationCleanupConfig.none()
        
        XCTAssertEqual(config.cleanupMode, .none)
        XCTAssertEqual(config.maxStoredNotifications, 100)
        XCTAssertEqual(config.maxNotificationAgeDays, 30)
    }
    
    func testCountBasedFactoryMethod() {
        let config = NotificationCleanupConfig.countBased()
        
        XCTAssertEqual(config.cleanupMode, .countBased)
        XCTAssertEqual(config.maxStoredNotifications, 100)
    }
    
    func testCountBasedFactoryMethodWithCustomValue() {
        let config = NotificationCleanupConfig.countBased(maxNotifications: 50)
        
        XCTAssertEqual(config.cleanupMode, .countBased)
        XCTAssertEqual(config.maxStoredNotifications, 50)
    }
    
    func testAgeBasedFactoryMethod() {
        let config = NotificationCleanupConfig.ageBased()
        
        XCTAssertEqual(config.cleanupMode, .ageBased)
        XCTAssertEqual(config.maxNotificationAgeDays, 30)
    }
    
    func testAgeBasedFactoryMethodWithCustomValue() {
        let config = NotificationCleanupConfig.ageBased(maxAgeDays: 7)
        
        XCTAssertEqual(config.cleanupMode, .ageBased)
        XCTAssertEqual(config.maxNotificationAgeDays, 7)
    }
    
    func testHybridFactoryMethod() {
        let config = NotificationCleanupConfig.hybrid()
        
        XCTAssertEqual(config.cleanupMode, .hybrid)
        XCTAssertEqual(config.maxStoredNotifications, 100)
        XCTAssertEqual(config.maxNotificationAgeDays, 30)
    }
    
    func testHybridFactoryMethodWithCustomValues() {
        let config = NotificationCleanupConfig.hybrid(
            maxNotifications: 50,
            maxAgeDays: 14
        )
        
        XCTAssertEqual(config.cleanupMode, .hybrid)
        XCTAssertEqual(config.maxStoredNotifications, 50)
        XCTAssertEqual(config.maxNotificationAgeDays, 14)
    }
    
    // MARK: - CleanupMode Tests
    
    func testCleanupModeAllCases() {
        let allModes = NotificationCleanupConfig.CleanupMode.allCases
        XCTAssertEqual(allModes.count, 4)
        XCTAssertTrue(allModes.contains(.none))
        XCTAssertTrue(allModes.contains(.countBased))
        XCTAssertTrue(allModes.contains(.ageBased))
        XCTAssertTrue(allModes.contains(.hybrid))
    }
    
    func testCleanupModeRawValues() {
        XCTAssertEqual(NotificationCleanupConfig.CleanupMode.none.rawValue, "NONE")
        XCTAssertEqual(NotificationCleanupConfig.CleanupMode.countBased.rawValue, "COUNT_BASED")
        XCTAssertEqual(NotificationCleanupConfig.CleanupMode.ageBased.rawValue, "AGE_BASED")
        XCTAssertEqual(NotificationCleanupConfig.CleanupMode.hybrid.rawValue, "HYBRID")
    }
    
    // MARK: - Sendable Tests
    
    func testSendable() async {
        let config = NotificationCleanupConfig.hybrid(maxNotifications: 50, maxAgeDays: 14)
        
        await Task {
            XCTAssertEqual(config.cleanupMode, .hybrid)
            XCTAssertEqual(config.maxStoredNotifications, 50)
            XCTAssertEqual(config.maxNotificationAgeDays, 14)
        }.value
    }
    
    func testCleanupModeSendable() async {
        let mode: NotificationCleanupConfig.CleanupMode = .ageBased
        
        await Task {
            XCTAssertEqual(mode, .ageBased)
        }.value
    }
}
