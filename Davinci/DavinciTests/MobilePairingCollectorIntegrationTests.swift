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
    func testCancelledOutcomeSerializesAsActionFormDataWithoutActionKey() {
        let collector = MobilePairingCollector(with: [
            "type": "MOBILE_PAIRING",
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
            "type": "MOBILE_PAIRING",
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
