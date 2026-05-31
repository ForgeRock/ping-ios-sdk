//
//  LabelCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import XCTest
@testable import PingDavinci

class LabelCollectorTests: XCTestCase {

    // MARK: - Parsing / Initialization

    func testInitializesContentWithProvidedValue() {

        let jsonObject: [String: String] = [
            "content": "Test Content",
            "key": "Test Key",
        ]

        let labelCollector = LabelCollector(with: jsonObject)

        XCTAssertEqual("Test Content", labelCollector.content)
        XCTAssertEqual("Test Key", labelCollector.key)
    }

    func testInitializesContentWithEmptyStringWhenNoValueProvided() {

        let jsonObject: [String: String] = [:]

        let labelCollector = LabelCollector(with: jsonObject)

        XCTAssertEqual("", labelCollector.content)
    }

    func testInitializationWithRichContentTwoLinks() {
        let input: [String: Any] = [
            "type": "LABEL",
            "key": "tos-label",
            "content": "Please read our Terms of Service and Privacy Policy",
            "richContent": [
                "content": "Please read our {{tosLink}} and {{privacyLink}}",
                "replacements": [
                    "tosLink": [
                        "value": "Terms of Service",
                        "href": "https://www.example.com/tos",
                        "type": "link",
                        "target": "_blank"
                    ],
                    "privacyLink": [
                        "value": "Privacy Policy",
                        "href": "https://www.example.com/privacy",
                        "type": "link",
                        "target": "_self"
                    ]
                ]
            ]
        ]

        let collector = LabelCollector(with: input)

        XCTAssertNotNil(collector.richContent)
        XCTAssertEqual(collector.content, "Please read our Terms of Service and Privacy Policy")
        XCTAssertEqual(collector.richContent?.content, "Please read our {{tosLink}} and {{privacyLink}}")
        XCTAssertEqual(collector.richContent?.replacements.count, 2)

        let tosLink = collector.richContent?.replacements["tosLink"]
        XCTAssertEqual(tosLink?.value, "Terms of Service")
        XCTAssertEqual(tosLink?.href, "https://www.example.com/tos")
        XCTAssertEqual(tosLink?.type, "link")
        XCTAssertEqual(tosLink?.target, "_blank")

        let privacyLink = collector.richContent?.replacements["privacyLink"]
        XCTAssertEqual(privacyLink?.value, "Privacy Policy")
        XCTAssertEqual(privacyLink?.href, "https://www.example.com/privacy")
        XCTAssertEqual(privacyLink?.type, "link")
        XCTAssertEqual(privacyLink?.target, "_self")
    }

    func testInitializationWithoutRichContent() {
        let input: [String: Any] = [
            "key": "plain-label",
            "content": "This is plain label text"
        ]

        let collector = LabelCollector(with: input)

        XCTAssertNil(collector.richContent)
        XCTAssertEqual(collector.content, "This is plain label text")
    }

    func testRichContentWithNoReplacementsKey() {
        let input: [String: Any] = [
            "type": "LABEL",
            "key": "notice-label",
            "content": "Please review this notice",
            "richContent": [
                "content": "Please review this notice"
            ]
        ]

        let collector = LabelCollector(with: input)

        XCTAssertNotNil(collector.richContent)
        XCTAssertEqual(collector.richContent?.content, "Please review this notice")
        XCTAssertEqual(collector.richContent?.replacements.count, 0)
        XCTAssertEqual(collector.content, "Please review this notice")
    }

    func testRichContentMissingContentStringYieldsNilRichContent() {
        let input: [String: Any] = [
            "type": "LABEL",
            "key": "bad-label",
            "content": "Fallback plain text",
            "richContent": [
                "replacements": [
                    "link1": [
                        "value": "Click",
                        "href": "https://example.com",
                        "type": "link",
                        "target": "_blank"
                    ]
                ]
            ]
        ]

        let collector = LabelCollector(with: input)

        XCTAssertNil(collector.richContent)
        XCTAssertEqual(collector.content, "Fallback plain text")
    }

    func testRichContentReplacementOptionalFieldsAreNilWhenAbsent() {
        let input: [String: Any] = [
            "type": "LABEL",
            "key": "label-key",
            "content": "Plain text",
            "richContent": [
                "content": "See {{item}}",
                "replacements": [
                    "item": [
                        "value": "details",
                        "type": "text"
                    ]
                ]
            ]
        ]

        let collector = LabelCollector(with: input)

        XCTAssertNotNil(collector.richContent)
        let item = collector.richContent?.replacements["item"]
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.value, "details")
        XCTAssertEqual(item?.type, "text")
        XCTAssertNil(item?.href)
        XCTAssertNil(item?.target)
    }

    func testContentPropertyUnchangedByRichContentPresence() {
        let inputs: [[String: Any]] = [
            [
                "key": "k1",
                "content": "Hello World",
                "richContent": ["content": "Hello {{w}}", "replacements": ["w": ["value": "World", "type": "text"]]]
            ],
            [
                "key": "k2",
                "content": "",
                "richContent": ["content": "{{x}}", "replacements": ["x": ["value": "y", "type": "text"]]]
            ]
        ]

        let expected = ["Hello World", ""]

        for (index, input) in inputs.enumerated() {
            let collector = LabelCollector(with: input)
            XCTAssertEqual(collector.content, expected[index])
        }
    }

    func testIdPropertyReturnsKey() {
        let input: [String: Any] = [
            "key": "my-label-key",
            "content": "Some text"
        ]
        let collector = LabelCollector(with: input)
        XCTAssertEqual(collector.id, "my-label-key")
        XCTAssertEqual(collector.id, collector.key)
    }

    func testPayloadAlwaysReturnsNil() {
        let plain: [String: Any] = ["key": "k", "content": "c"]
        XCTAssertNil(LabelCollector(with: plain).payload())

        let rich: [String: Any] = [
            "key": "k",
            "content": "c",
            "richContent": [
                "content": "{{x}}",
                "replacements": ["x": ["value": "y", "href": "https://example.com", "type": "link", "target": "_blank"]]
            ]
        ]
        XCTAssertNil(LabelCollector(with: rich).payload())
    }

    // Verifies that LabelCollector and BooleanCollector accept the same richContent JSON shape
    // (structural equivalence, not a shared instance).
    func testRichContentTypeIsSharedBetweenCollectors() {
        let richInput: [String: Any] = [
            "content": "template {{link}}",
            "replacements": [
                "link": ["value": "click", "href": "https://example.com", "type": "link", "target": "_self"]
            ]
        ]
        let labelInput: [String: Any] = ["key": "k", "content": "c", "richContent": richInput]
        let boolInput: [String: Any] = ["key": "k", "label": "l", "richContent": richInput]

        let label = LabelCollector(with: labelInput)
        let bool = BooleanCollector(with: boolInput)

        guard let lrc = label.richContent, let brc = bool.richContent else {
            XCTFail("Both collectors must produce non-nil richContent from the same JSON shape")
            return
        }
        XCTAssertEqual(lrc.content, brc.content)
        XCTAssertEqual(lrc.replacements["link"]?.href, brc.replacements["link"]?.href)
    }

    // MARK: - Combined ToS Scenario

    func testCombinedToSScenario() {
        let labelInput: [String: Any] = [
            "type": "LABEL",
            "key": "tos-label",
            "content": "Please read our Terms of Service",
            "richContent": [
                "content": "Please read our {{tosLink}}",
                "replacements": [
                    "tosLink": [
                        "value": "Terms of Service",
                        "href": "https://www.example.com/tos",
                        "type": "link",
                        "target": "_blank"
                    ]
                ]
            ]
        ]

        let booleanInput: [String: Any] = [
            "type": "SINGLE_CHECKBOX",
            "inputType": "BOOLEAN",
            "key": "agree-checkbox",
            "label": "I agree",
            "required": true,
            "richContent": [
                "content": "I agree to the {{tosLink}}",
                "replacements": [
                    "tosLink": [
                        "value": "Terms of Service",
                        "href": "https://www.example.com/tos",
                        "type": "link",
                        "target": "_blank"
                    ]
                ]
            ]
        ]

        let labelCollector = LabelCollector(with: labelInput)
        let booleanCollector = BooleanCollector(with: booleanInput)

        XCTAssertEqual(labelCollector.key, "tos-label")
        XCTAssertEqual(labelCollector.content, "Please read our Terms of Service")
        XCTAssertNotNil(labelCollector.richContent)
        XCTAssertEqual(labelCollector.richContent?.content, "Please read our {{tosLink}}")
        XCTAssertEqual(labelCollector.richContent?.replacements.count, 1)
        let labelTosLink = labelCollector.richContent?.replacements["tosLink"]
        XCTAssertEqual(labelTosLink?.value, "Terms of Service")
        XCTAssertEqual(labelTosLink?.href, "https://www.example.com/tos")
        XCTAssertEqual(labelTosLink?.type, "link")
        XCTAssertEqual(labelTosLink?.target, "_blank")

        XCTAssertNotNil(booleanCollector.richContent)
        XCTAssertEqual(booleanCollector.richContent?.content, "I agree to the {{tosLink}}")
        XCTAssertEqual(booleanCollector.richContent?.replacements.count, 1)
        let boolTosLink = booleanCollector.richContent?.replacements["tosLink"]
        XCTAssertEqual(boolTosLink?.value, "Terms of Service")
        XCTAssertEqual(boolTosLink?.href, "https://www.example.com/tos")
        XCTAssertEqual(boolTosLink?.type, "link")
        XCTAssertEqual(boolTosLink?.target, "_blank")
    }
}
