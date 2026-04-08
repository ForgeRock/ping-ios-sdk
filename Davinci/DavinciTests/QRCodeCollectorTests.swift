//
//  QRCodeCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci

class QRCodeCollectorTests: XCTestCase {

    // MARK: - Initialization

    func testInitializesWithDataURIContent() {
        let sampleData = "Hello QR Code".data(using: .utf8)!
        let base64String = sampleData.base64EncodedString()
        let json: [String: Any] = [
            "key": "qr-field",
            "content": "data:image/png;base64,\(base64String)"
        ]

        let collector = QRCodeCollector(with: json)

        XCTAssertEqual(collector.id, "qr-field")
        XCTAssertNotNil(collector.imageData)
        XCTAssertEqual(collector.imageData, sampleData)
    }

    func testInitializesWithoutContentKey() {
        let json: [String: Any] = ["key": "qr-field"]

        let collector = QRCodeCollector(with: json)

        XCTAssertNil(collector.imageData)
        XCTAssertEqual(collector.id, "qr-field")
    }

    func testEmptyJsonInitialization() {
        let collector = QRCodeCollector(with: [:])

        XCTAssertEqual(collector.id, "")
        XCTAssertNil(collector.imageData)
        XCTAssertEqual(collector.fallbackText, "")
    }

    func testInitializesWithFallbackText() {
        let json: [String: Any] = [
            "key": "qr-field",
            "fallbackText": "Use code ABC-123 instead"
        ]

        let collector = QRCodeCollector(with: json)

        XCTAssertEqual(collector.fallbackText, "Use code ABC-123 instead")
    }

    func testFallbackTextDefaultsToEmpty() {
        let collector = QRCodeCollector(with: ["key": "qr-field"])
        XCTAssertEqual(collector.fallbackText, "")
    }

    func testStripsDataURIPrefixBeforeDecoding() {
        // Different MIME types should all be handled correctly.
        let sampleData = "PingOne".data(using: .utf8)!
        let base64 = sampleData.base64EncodedString()
        for mimeType in ["image/png", "image/jpeg", "image/svg+xml"] {
            let json: [String: Any] = ["content": "data:\(mimeType);base64,\(base64)"]
            let collector = QRCodeCollector(with: json)
            XCTAssertEqual(collector.imageData, sampleData, "Failed for MIME type \(mimeType)")
        }
    }

    func testInitializesWithEmptyContentString() {
        let json: [String: Any] = [
            "key": "qr-field",
            "content": ""
        ]

        let collector = QRCodeCollector(with: json)
        XCTAssertEqual(collector.id, "qr-field")
    }

    func testInitializesWithMalformedBase64Content() {
        let json: [String: Any] = [
            "key": "qr-field",
            "content": "data:image/png;base64,%%%not-valid-base64!!!"
        ]

        let collector = QRCodeCollector(with: json)

        XCTAssertEqual(collector.id, "qr-field")
        XCTAssertNil(collector.imageData)
    }

    // MARK: - id

    func testIdReflectsKeyFromJson() {
        let json: [String: Any] = ["key": "my-qr-code"]
        let collector = QRCodeCollector(with: json)
        XCTAssertEqual(collector.id, "my-qr-code")
    }

    func testIdIsEmptyWhenKeyMissing() {
        let collector = QRCodeCollector(with: [:])
        XCTAssertEqual(collector.id, "")
    }

    // MARK: - payload

    func testPayloadReturnsNil() {
        let collector = QRCodeCollector(with: [:])
        XCTAssertNil(collector.payload())
    }

    // MARK: - initialize

    func testInitializeWithValueIsNoOp() {
        let sampleData = "Test".data(using: .utf8)!
        let json: [String: Any] = ["content": "data:image/png;base64,\(sampleData.base64EncodedString())"]
        let collector = QRCodeCollector(with: json)
        let originalData = collector.imageData

        collector.initialize(with: "some override value")

        // imageData should not change — this collector is display-only
        XCTAssertEqual(collector.imageData, originalData)
    }

    // MARK: - imageData round-trip

    func testImageDataRoundTrip() {
        let originalString = "PingOne DaVinci QR"
        let originalData = originalString.data(using: .utf8)!
        let json: [String: Any] = ["content": "data:image/png;base64,\(originalData.base64EncodedString())"]

        let collector = QRCodeCollector(with: json)

        XCTAssertNotNil(collector.imageData)
        let decoded = String(data: collector.imageData!, encoding: .utf8)
        XCTAssertEqual(decoded, originalString)
    }
}
