//
//  SessionTests.swift
//  OrchestrateTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingOrchestrate

final class SessionTests: XCTestCase {
    
    func testEmptySessionValueShouldReturnEmptyString() {
        XCTAssertEqual("", EmptySession().value)
    }
    
    func testSessionValueShouldReturnCorrectSessionValue() {
        let session = MockSession()
        XCTAssertEqual("session_value", session.value)
    }
    
    struct MockSession: Session {
        var value: String = "session_value"
    }
    
}
