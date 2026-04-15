// 
//  ProtectLifecycleConfigTests.swift
//  Protect
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect


final class ProtectLifecycleConfigTests: XCTestCase {
    
    func testDefaultValues() {
        let config = ProtectLifecycleConfig()
        
        // Inherited properties
        XCTAssertNil(config.envId)
        XCTAssertEqual(config.deviceAttributesToIgnore, [])
        XCTAssertNil(config.customHost)
        XCTAssertFalse(config.isConsoleLogEnabled)
        XCTAssertFalse(config.isLazyMetadata)
        XCTAssertTrue(config.isBehavioralDataCollection)
        
        // Lifecycle-specific properties
        XCTAssertFalse(config.pauseBehavioralDataOnSuccess)
        XCTAssertFalse(config.resumeBehavioralDataOnStart)
    }
    
    func testSettingLifecycleProperties() {
        let config = ProtectLifecycleConfig()
        
        config.pauseBehavioralDataOnSuccess = true
        config.resumeBehavioralDataOnStart = true
        
        XCTAssertTrue(config.pauseBehavioralDataOnSuccess)
        XCTAssertTrue(config.resumeBehavioralDataOnStart)
    }
    
    func testInheritanceFromProtectConfig() {
        let config = ProtectLifecycleConfig()
        
        // Set parent class properties
        config.envId = "lifecycle-env"
        config.isConsoleLogEnabled = true
        
        XCTAssertEqual(config.envId, "lifecycle-env")
        XCTAssertTrue(config.isConsoleLogEnabled)
    }
}
