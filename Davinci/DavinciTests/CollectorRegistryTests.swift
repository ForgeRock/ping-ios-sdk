//
//  CollectorRegistryTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
import PingDavinciPlugin
@testable import PingDavinci

@MainActor
final class CollectorRegistryTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await CollectorFactory.shared.reset()
    }

    override func tearDown() async throws {
        await CollectorFactory.shared.reset()
        try await super.tearDown()
    }

    func testShouldRegisterCollector() async {
        let davinci = DaVinci.createDaVinci()

        // Give plugin registration a brief moment to complete to avoid race
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["inputType": "ACTION"],
            ["type": "PASSWORD_VERIFY"],
            ["inputType": "ACTION"],
            ["type": "LABEL"],
            ["inputType": "SINGLE_SELECT"],
            ["inputType": "SINGLE_SELECT"],
            ["inputType": "MULTI_SELECT"],
            ["inputType": "MULTI_SELECT"],
        ]

        let collectors = await CollectorFactory.shared.collector(daVinci: davinci, from: jsonArray)
        XCTAssertEqual(collectors.count, 11)
        if collectors.count == 11 {
            XCTAssertTrue(collectors[0] is TextCollector)
            XCTAssertTrue(collectors[1] is PasswordCollector)
            XCTAssertTrue(collectors[2] is SubmitCollector)
            XCTAssertTrue(collectors[3] is FlowCollector)
            XCTAssertTrue(collectors[4] is PasswordCollector)
            XCTAssertTrue(collectors[5] is FlowCollector)
            XCTAssertTrue(collectors[6] is LabelCollector)
            XCTAssertTrue(collectors[7] is SingleSelectCollector)
            XCTAssertTrue(collectors[8] is SingleSelectCollector)
            XCTAssertTrue(collectors[9] is MultiSelectCollector)
            XCTAssertTrue(collectors[10] is MultiSelectCollector)
        }
    }

    func testShouldIgnoreUnknownCollector() async {
        let davinci = DaVinci.createDaVinci()
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["inputType": "ACTION"],
            ["type": "UNKNOWN"]
        ]

        let collectors = await CollectorFactory.shared.collector(daVinci: davinci, from: jsonArray)
        XCTAssertEqual(collectors.count, 4)
    }
}
