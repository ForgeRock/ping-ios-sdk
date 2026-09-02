//
//  MobilePairingCollectorIntegrationTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import XCTest
import PingDavinciPlugin
import PingOneMFA
@testable import PingDavinci

final class MobilePairingCollectorIntegrationTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await CollectorFactory.shared.reset()
    }

    override func tearDown() async throws {
        await CollectorFactory.shared.reset()
        try await super.tearDown()
    }

    func testImmediatelyDiscoversOptionalMobilePairingCollector() async {
        let daVinci = DaVinci.createDaVinci()
        let fields: [[String: any Sendable]] = [[
            "type": Constants.MOBILE_PAIRING,
            "key": "mobilePairing",
            "pairingKey": "key"
        ]]
        let response: [String: Any] = [
            Constants.form: [
                Constants.components: [
                    Constants.fields: fields
                ]
            ]
        ]

        let collectors = await Form.parse(daVinci: daVinci, json: response)

        XCTAssertEqual(collectors.count, 1)
        XCTAssertTrue(collectors.first is MobilePairingCollector)
    }

    func testImmediatelyDiscoversInputTypeMobilePairingCollector() async {
        let daVinci = DaVinci.createDaVinci()
        let fields: [[String: any Sendable]] = [[
            "inputType": Constants.MOBILE_PAIRING,
            "type": "TEXT",
            "key": "mobilePairing",
            "pairingKey": "key"
        ]]
        let response: [String: Any] = [
            Constants.form: [
                Constants.components: [
                    Constants.fields: fields
                ]
            ]
        ]

        let collectors = await Form.parse(daVinci: daVinci, json: response)

        XCTAssertEqual(collectors.count, 1)
        XCTAssertTrue(collectors.first is MobilePairingCollector)
    }

    func testCancelledOutcomeSerializesAsActionFormDataWithoutActionKey() {
        let collector = MobilePairingCollector(with: [
            "type": Constants.MOBILE_PAIRING,
            "key": "mobilePairing",
            "pairingKey": "key"
        ])
        collector.cancel()

        let collectors: Collectors = [collector]
        let json = collectors.asJson()
        let formData = json[Constants.formData] as? [String: Any]
        let mobilePairing = formData?["mobilePairing"] as? [String: Any]
        let error = mobilePairing?["error"] as? [String: Any]

        XCTAssertEqual(collectors.eventType(), "action")
        XCTAssertNil(json[Constants.actionKey])
        XCTAssertEqual(error?["code"] as? String, "USER_CANCELLED")
        XCTAssertNil(mobilePairing?["mobilePairing"])
    }

    func testUnsetOutcomeIsOmittedFromFormDataAndEventType() {
        let collector = MobilePairingCollector(with: [
            "type": Constants.MOBILE_PAIRING,
            "key": "customKey",
            "pairingKey": "key"
        ])
        let collectors: Collectors = [collector]
        let json = collectors.asJson()
        let formData = json[Constants.formData] as? [String: Any]

        XCTAssertTrue(formData?.isEmpty == true)
        XCTAssertNil(collectors.eventType())
        XCTAssertNil(json[Constants.actionKey])
    }
}
