//
//  ReadOnlyTextCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import XCTest
@testable import PingDavinci

class ReadOnlyTextCollectorTests: XCTestCase {
    
    private func buildFullAgreementJson() -> [String: Any] {
        return [
            "type": "AGREEMENT",
            "inputType": "READ_ONLY_TEXT",
            "key": "agreement",
            "content": "This is example agreement text, you can edit this text in the agreements section.",
            "titleEnabled": true,
            "title": "Terms of Service Agreement",
            "agreement": [
                "id": "6ff30c9e-cd98-4fe5-85ca-01111ca20702",
                "useDynamicAgreement": false
            ],
            "enabled": true
        ]
    }
    
    func testInitializesKeyFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual("agreement", collector.key)
    }
    
    func testInitializesTypeFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual("AGREEMENT", collector.type)
    }
    
    func testInitializesContentFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual(
            "This is example agreement text, you can edit this text in the agreements section.",
            collector.content
        )
    }
    
    func testInitializesTitleFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual("Terms of Service Agreement", collector.title)
    }
    
    func testInitializesTitleEnabledFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertTrue(collector.titleEnabled)
    }
    
    func testInitializesEnabledFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertTrue(collector.enabled)
    }
    
    func testInitializesAgreementIdFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual("6ff30c9e-cd98-4fe5-85ca-01111ca20702", collector.agreementId)
    }
    
    func testInitializesUseDynamicAgreementFromJson() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertFalse(collector.useDynamicAgreement)
    }
    
    func testIdReturnsKey() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertEqual("agreement", collector.id)
    }
    
    func testInitializesWithDefaultsWhenJsonIsEmpty() {
        let collector = ReadOnlyTextCollector(with: [:])
        XCTAssertEqual("", collector.key)
        XCTAssertEqual("", collector.type)
        XCTAssertEqual("", collector.content)
        XCTAssertEqual("", collector.title)
        XCTAssertFalse(collector.titleEnabled)
        XCTAssertTrue(collector.enabled) // defaults to true
        XCTAssertEqual("", collector.agreementId)
        XCTAssertFalse(collector.useDynamicAgreement)
    }
    
    func testTitleEnabledFalseWhenNotProvided() {
        let input: [String: Any] = ["key": "agreement"]
        let collector = ReadOnlyTextCollector(with: input)
        XCTAssertFalse(collector.titleEnabled)
    }
    
    func testPayloadReturnsNil() {
        let collector = ReadOnlyTextCollector(with: buildFullAgreementJson())
        XCTAssertNil(collector.payload())
    }
}
