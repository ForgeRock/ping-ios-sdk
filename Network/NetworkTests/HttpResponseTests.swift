//
//  HttpResponseTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class HttpResponseTests: XCTestCase {
    func testIsSuccessRange() {
        XCTAssertTrue(200.isSuccess())
        XCTAssertTrue(250.isSuccess())
        XCTAssertTrue(299.isSuccess())
        XCTAssertFalse(199.isSuccess())
        XCTAssertFalse(300.isSuccess())
    }

    func testIsRedirectRange() {
        XCTAssertTrue(300.isRedirect())
        XCTAssertTrue(350.isRedirect())
        XCTAssertTrue(399.isRedirect())
        XCTAssertFalse(299.isRedirect())
        XCTAssertFalse(400.isRedirect())
    }

    func testIsClientErrorRange() {
        XCTAssertTrue(400.isClientError())
        XCTAssertTrue(450.isClientError())
        XCTAssertTrue(499.isClientError())
        XCTAssertFalse(399.isClientError())
        XCTAssertFalse(500.isClientError())
    }

    func testIsServerErrorRange() {
        XCTAssertTrue(500.isServerError())
        XCTAssertTrue(550.isServerError())
        XCTAssertTrue(599.isServerError())
        XCTAssertFalse(499.isServerError())
        XCTAssertFalse(600.isServerError())
    }
}
