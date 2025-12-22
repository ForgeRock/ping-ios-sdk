//
//  CollectorRegistryTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
import PingDavinciPlugin
@testable import PingDavinci

actor AsyncLock {
    func run<T>(_ body: @Sendable () async throws -> T) async rethrows -> T {
        try await body()
    }
}

@MainActor
final class CollectorRegistryTests: XCTestCase {

    private static let lock = AsyncLock()

    func testShouldRegisterCollector() async throws {
        try await Self.lock.run({ @Sendable () async throws -> Void in
            await CollectorFactory.shared.reset()

            let davinci = DaVinci.createDaVinci()
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
        })
    }

    func testShouldIgnoreUnknownCollector() async throws {
        try await Self.lock.run({ @Sendable () async throws -> Void in
            await CollectorFactory.shared.reset()

            let davinci = DaVinci.createDaVinci()
            let jsonArray: [[String: Any]] = [
                ["type": "TEXT"],
                ["type": "PASSWORD"],
                ["type": "SUBMIT_BUTTON"],
                ["inputType": "ACTION"],
                ["type": "UNKNOWN"]
            ]

            let collectors = await CollectorFactory.shared.collector(daVinci: davinci, from: jsonArray)
            XCTAssertEqual(collectors.count, 4)
        })
    }
}
