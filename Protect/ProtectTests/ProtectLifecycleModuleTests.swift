// 
//  ProtectLifecycleModuleTests.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect
@testable import PingOrchestrate

final class ProtectLifecycleTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testInitConfiguresAndInitializesProtect() async throws {
        // Given
        var configApplied: ProtectConfig?
        
        let workflow = Workflow.createWorkflow {
            $0.module(ProtectLifecycleModule.config) {
                $0.envId = "env"
                $0.deviceAttributesToIgnore = ["a"]
                $0.customHost = "host"
                $0.isConsoleLogEnabled = true
                $0.isLazyMetadata = true
                $0.isBehavioralDataCollection = false
                $0.pauseBehavioralDataOnSuccess = true
                $0.resumeBehavioralDataOnStart = true
            }
        }
        
        // When
        try await workflow.initialize()
        
        // Then
        configApplied = await Protect.protectConfig
        
        XCTAssertEqual(configApplied?.envId, "env")
        XCTAssertEqual(configApplied?.deviceAttributesToIgnore, ["a"])
        XCTAssertEqual(configApplied?.customHost, "host")
        XCTAssertEqual(configApplied?.isConsoleLogEnabled, true)
        XCTAssertEqual(configApplied?.isLazyMetadata, true)
        XCTAssertEqual(configApplied?.isBehavioralDataCollection, false)
    }
}
