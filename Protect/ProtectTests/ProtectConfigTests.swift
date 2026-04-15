// 
//  ProtectConfigTests.swift
//  Protect
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect


// MARK: - ProtectConfig Tests

final class ProtectConfigTests: XCTestCase {
    
    func testDefaultValues() {
        let config = ProtectConfig()
        
        XCTAssertNil(config.envId)
        XCTAssertEqual(config.deviceAttributesToIgnore, [])
        XCTAssertNil(config.customHost)
        XCTAssertFalse(config.isConsoleLogEnabled)
        XCTAssertFalse(config.isLazyMetadata)
        XCTAssertTrue(config.isBehavioralDataCollection)
    }
    
    func testSettingAllProperties() {
        let config = ProtectConfig()
        
        config.envId = "test-env-id"
        config.deviceAttributesToIgnore = ["attr1", "attr2"]
        config.customHost = "custom.host.com"
        config.isConsoleLogEnabled = true
        config.isLazyMetadata = true
        config.isBehavioralDataCollection = false
        
        XCTAssertEqual(config.envId, "test-env-id")
        XCTAssertEqual(config.deviceAttributesToIgnore, ["attr1", "attr2"])
        XCTAssertEqual(config.customHost, "custom.host.com")
        XCTAssertTrue(config.isConsoleLogEnabled)
        XCTAssertTrue(config.isLazyMetadata)
        XCTAssertFalse(config.isBehavioralDataCollection)
    }
}
