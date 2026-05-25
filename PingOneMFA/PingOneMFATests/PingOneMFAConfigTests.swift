//
//  PingOneMFAConfigTests.swift
//  PingOneMFA
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOneMFA


// MARK: - PingOneMFAConfig Tests

final class PingOneMFAConfigTests: XCTestCase {

    func testDefaultValues() {
        let config = PingOneMFAConfig()

        XCTAssertNil(config.geo)
    }

    func testSettingGeoNorthAmerica() {
        let config = PingOneMFAConfig()

        config.geo = .northAmerica

        XCTAssertEqual(config.geo, .northAmerica)
    }

    func testSettingGeoEurope() {
        let config = PingOneMFAConfig()

        config.geo = .europe

        XCTAssertEqual(config.geo, .europe)
    }

    func testSettingGeoAustralia() {
        let config = PingOneMFAConfig()

        config.geo = .australia

        XCTAssertEqual(config.geo, .australia)
    }

    func testSettingGeoCanada() {
        let config = PingOneMFAConfig()

        config.geo = .canada

        XCTAssertEqual(config.geo, .canada)
    }

    func testSettingGeoSingapore() {
        let config = PingOneMFAConfig()

        config.geo = .singapore

        XCTAssertEqual(config.geo, .singapore)
    }

    func testOverridingGeo() {
        let config = PingOneMFAConfig()

        config.geo = .northAmerica
        XCTAssertEqual(config.geo, .northAmerica)

        config.geo = .europe
        XCTAssertEqual(config.geo, .europe)
    }
}
