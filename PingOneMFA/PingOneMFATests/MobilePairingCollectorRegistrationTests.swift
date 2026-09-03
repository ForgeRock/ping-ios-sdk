//
//  MobilePairingCollectorRegistrationTests.swift
//  PingOneMFATests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingDavinciPlugin
@testable import PingOneMFA

final class MobilePairingCollectorRegistrationTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await CollectorFactory.shared.reset()
    }

    override func tearDown() async throws {
        await CollectorFactory.shared.reset()
        try await super.tearDown()
    }

    func testInitializerIsVisibleToObjectiveCRuntime() {
        XCTAssertNotNil(NSClassFromString("PingOneMFA.CollectorInitializer"))
    }

    func testRegistersMobilePairingCollector() async {
        await CollectorInitializer.registerCollectorsAsync()
        let workflow = DaVinci.createWorkflow()
        let collectors = await CollectorFactory.shared.collector(
            daVinci: workflow,
            from: [["type": "MOBILE_PAIRING", "key": "mobilePairing", "pairingKey": "key"]]
        )
        XCTAssertEqual(collectors.count, 1)
        XCTAssertTrue(collectors.first is MobilePairingCollector)
    }
}
