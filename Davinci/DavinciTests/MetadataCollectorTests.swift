//
//  MetadataCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import XCTest
import PingDavinciPlugin
@testable import PingDavinci

class MetadataCollectorTests: XCTestCase {

    private func buildJson() -> [String: Any] {
        return [
            "type": "METADATA",
            "key": "sdkMetadata",
            "payload": [
                "sdk": "PROTECT",
                "action": "INITIALIZE",
                "behavioralDataCollection": true
            ]
        ]
    }

    func testParsesKeyTypeAndMetadata() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertEqual("sdkMetadata", collector.key)
        XCTAssertEqual("METADATA", collector.type)
        XCTAssertEqual("PROTECT", collector.metadata["sdk"] as? String)
        XCTAssertEqual("INITIALIZE", collector.metadata["action"] as? String)
        XCTAssertEqual(true, collector.metadata["behavioralDataCollection"] as? Bool)
    }

    func testIdEqualsKey() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertEqual(collector.key, collector.id)
    }

    func testDefaultsWhenJsonEmpty() {
        let collector = MetadataCollector(with: [:])
        XCTAssertEqual("", collector.key)
        XCTAssertEqual("", collector.type)
        XCTAssertTrue(collector.metadata.isEmpty)
    }

    func testMetadataDefaultsWhenNotDictionary() {
        // Spec §6.6 rejects non-object payloads server-side, but the collector
        // must not crash on such input either.
        let collector = MetadataCollector(with: [
            "type": "METADATA",
            "key": "sdkMetadata",
            "payload": ["arrays", "are", "invalid"]
        ])
        XCTAssertTrue(collector.metadata.isEmpty)
    }

    func testPayloadIsNilBeforeSetResult() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertNil(collector.payload())
        XCTAssertNil(collector.anyPayload())
    }

    func testSetResultProducesPayload() {
        let collector = MetadataCollector(with: buildJson())
        collector.setResult(["verified": true, "score": 92])
        let payload = collector.payload()
        XCTAssertEqual(true, payload?["verified"] as? Bool)
        XCTAssertEqual(92, payload?["score"] as? Int)

        let anyPayload = collector.anyPayload() as? [String: Any]
        XCTAssertEqual(true, anyPayload?["verified"] as? Bool)
    }

    func testInitializeIsNoOp() {
        // initialize(with:) must not pre-populate result from server-echoed data;
        // the result must always come from setResult(_:) or setError(...).
        let collector = MetadataCollector(with: buildJson())
        collector.initialize(with: ["foo": "bar"])
        XCTAssertNil(collector.payload())
    }

    func testInitializeIgnoresNonDictionary() {
        let collector = MetadataCollector(with: buildJson())
        collector.initialize(with: "not a dict")
        XCTAssertNil(collector.payload())
    }

    func testSetErrorProducesErrorEnvelope() {
        let collector = MetadataCollector(with: buildJson())
        collector.setError(code: "USER_CANCELLED", message: "User cancelled the operation")

        let payload = collector.payload()
        let error = payload?["error"] as? [String: Any]
        XCTAssertEqual("USER_CANCELLED", error?["code"] as? String)
        XCTAssertEqual("User cancelled the operation", error?["message"] as? String)
        XCTAssertNil(error?["isClientError"])
    }

    func testEventTypeIsAction() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertEqual("action", collector.eventType())
    }

    func testValidateRequiresResult() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertEqual([ValidationError.required], collector.validate())

        collector.setResult(["ok": true])
        XCTAssertTrue(collector.validate().isEmpty)
    }

    func testCloseClearsResult() {
        let collector = MetadataCollector(with: buildJson())
        collector.setResult(["ok": true])
        collector.close()
        XCTAssertNil(collector.payload())
    }

    func testActionKeyIsNilWhenNoResult() {
        let collector = MetadataCollector(with: buildJson())
        XCTAssertNil(collector.actionKey)
    }

    func testActionKeyIsIdWhenResultSet() {
        let collector = MetadataCollector(with: buildJson())
        collector.setResult(["ok": true])
        XCTAssertEqual("sdkMetadata", collector.actionKey)
    }

    // MARK: - Collectors pipeline integration

    func testCollectorsAsJsonProducesResumeEnvelope() {
        let collector = MetadataCollector(with: buildJson())
        collector.setResult(["verified": true])

        let collectors: Collectors = [collector]
        let json = collectors.asJson()

        XCTAssertEqual("sdkMetadata", json[Constants.actionKey] as? String)
        let formData = json[Constants.formData] as? [String: Any]
        let sdkMetadata = formData?["sdkMetadata"] as? [String: Any]
        XCTAssertEqual(true, sdkMetadata?["verified"] as? Bool)
    }

    func testCollectorsEventTypeIsActionWhenResultPresent() {
        let collector = MetadataCollector(with: buildJson())
        collector.setResult(["ok": true])
        let collectors: Collectors = [collector]
        XCTAssertEqual(Constants.action, collectors.eventType())
    }

    func testCollectorsAsJsonOmitsActionKeyWhenNoResult() {
        let collector = MetadataCollector(with: buildJson())
        let collectors: Collectors = [collector]
        let json = collectors.asJson()

        XCTAssertNil(json[Constants.actionKey])
        let formData = json[Constants.formData] as? [String: Any]
        XCTAssertTrue(formData?.isEmpty ?? false)
        XCTAssertNil(collectors.eventType())
    }
}
