//
//  ImageCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingDavinciPlugin
@testable import PingDavinci

class ImageCollectorTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        await CollectorFactory.shared.reset()
    }

    override func tearDown() async throws {
        await CollectorFactory.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func buildFullJson() -> [String: Any] {
        return [
            "type": "IMAGE",
            "key": "image-field",
            "imageUrl": "https://example.com/image.png",
            "description": "A sample image",
            "hyperlinkUrl": "https://example.com"
        ]
    }

    private func buildJsonWithoutHyperlink() -> [String: Any] {
        return [
            "type": "IMAGE",
            "key": "image-field",
            "imageUrl": "https://example.com/image.png",
            "description": "A sample image"
        ]
    }

    // MARK: - Initialization

    func testInitializesKeyFromJson() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertEqual(collector.key, "image-field")
    }

    func testInitializesImageUrlFromJson() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertEqual(collector.imageUrl, "https://example.com/image.png")
    }

    func testInitializesDescriptionFromJson() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertEqual(collector.description, "A sample image")
    }

    func testHyperlinkUrlIsPresentWhenProvided() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertNotNil(collector.hyperlinkUrl)
        XCTAssertEqual(collector.hyperlinkUrl, "https://example.com")
    }

    func testHyperlinkUrlIsNilWhenAbsent() {
        let collector = ImageCollector(with: buildJsonWithoutHyperlink())
        XCTAssertNil(collector.hyperlinkUrl)
    }

    func testEmptyJsonInitialization() {
        let collector = ImageCollector(with: [:])
        XCTAssertEqual(collector.key, "")
        XCTAssertEqual(collector.imageUrl, "")
        XCTAssertEqual(collector.description, "")
        XCTAssertNil(collector.hyperlinkUrl)
    }

    // MARK: - id

    func testIdReturnsKey() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertEqual(collector.id, collector.key)
    }

    // MARK: - payload

    func testPayloadReturnsNil() {
        let collector = ImageCollector(with: buildFullJson())
        XCTAssertNil(collector.payload())
    }

    // MARK: - CollectorFactory registration

    func testCollectorFactoryProducesImageCollector() async {
        let davinci = DaVinci.createDaVinci()
        try? await Task.sleep(nanoseconds: 100_000_000)

        let jsonArray: [[String: Any]] = [
            ["type": "IMAGE", "key": "img", "imageUrl": "https://example.com/img.png", "description": ""]
        ]
        let collectors = await CollectorFactory.shared.collector(daVinci: davinci, from: jsonArray)
        XCTAssertEqual(collectors.count, 1)
        XCTAssertTrue(collectors.first is ImageCollector, "Expected ImageCollector for type IMAGE")
    }

    // MARK: - initialize

    func testInitializeWithValueIsNoOp() {
        let collector = ImageCollector(with: buildFullJson())
        let originalKey = collector.key
        let originalImageUrl = collector.imageUrl
        let originalDescription = collector.description
        let originalHyperlinkUrl = collector.hyperlinkUrl

        collector.initialize(with: "some override value")

        XCTAssertEqual(collector.key, originalKey)
        XCTAssertEqual(collector.imageUrl, originalImageUrl)
        XCTAssertEqual(collector.description, originalDescription)
        XCTAssertEqual(collector.hyperlinkUrl, originalHyperlinkUrl)
    }
}
