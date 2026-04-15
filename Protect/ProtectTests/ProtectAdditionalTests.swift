//
//  ProtectAdditionalTests.swift
//  ProtectTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect
@testable import PingDavinciPlugin
@testable import PingJourneyPlugin

// MARK: - ProtectCallbacks Tests

final class ProtectCallbacksRegistrationTests: XCTestCase {
    
    func testRegisterCallbacks() {
        // Just verify the method exists and can be called without crashing
        ProtectCallbacks.registerCallbacks()
        XCTAssertTrue(true)
    }
}

// MARK: - ProtectCollector Registration Tests

final class ProtectCollectorRegistrationTests: XCTestCase {
    
    func testRegisterCollector() {
        // Just verify the method exists and can be called without crashing
        ProtectCollector.registerCollector()
        XCTAssertTrue(true)
    }
}

// MARK: - ProtectLifecycleModule Tests

final class ProtectLifecycleModuleTests: XCTestCase {
    
    func testInit() {
        let module = ProtectLifecycleModule()
        XCTAssertNotNil(module)
    }
}
