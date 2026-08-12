//
//  ImageCollectorE2ETest.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

/// E2E tests for ImageCollector — DaVinci IMAGE-type form field.
///
/// The test flow starts with a "Select Test Form" that presents a FlowCollector "Image" button.
/// Tapping it transitions to the "Automation - Image" showForm node which contains:
///
///   index 0 — LabelCollector  (key "title-text", richContent "Image Collector Test")
///   index 1 — ImageCollector  (key "image", description "Image Collector Test", raster imageUrl, hyperlinkUrl)
///   index 2 — SubmitCollector (key "submit", label "Continue")
///
/// Tapping Continue loops back to the Select Test Form.
class ImageCollectorE2ETest: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    // MARK: - Index constants

    private let imageButtonIndex = 1  // FlowCollector "Image" on Select Test Form
    private let labelIndex = 0        // LabelCollector (title-text) on Automation - Image
    private let imageIndex = 1        // ImageCollector (image) on Automation - Image
    private let submitIndex = 2       // SubmitCollector "Continue" on Automation - Image

    // MARK: - Expected values

    private let expectedNodeName = "Automation - Image"
    private let expectedImageKey = "image"
    private let expectedImageDescription = "Image Collector Test"
    private let expectedImageUrl = "https://img.magnific.com/free-photo/closeup-shot-beautiful-butterfly-with-interesting-textures-orange-petaled-flower_181624-7640.jpg"
    private let expectedHyperlinkUrl = "https://www.pingidentity.com/en.html"

    override func setUp() async throws {
        self.configFileName = "ConfigNew"
        try await super.setUp()

        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.acrValues = "14f7988fc922112d599a14c1016a6ec6"
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }

        await daVinci.daVinciUser()?.logout()
    }

    // MARK: - Helper

    /// Navigates from start() to the "Automation - Image" form node.
    private func navigateToImageForm() async -> ContinueNode? {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return nil
        }
        XCTAssertEqual("Select Test Form", startNode.name)
        guard let imageButton = startNode.collectors[imageButtonIndex] as? FlowCollector else {
            XCTFail("Expected FlowCollector at index \(imageButtonIndex)")
            return nil
        }
        XCTAssertEqual("Image", imageButton.label)
        imageButton.value = "click"

        guard let imageFormNode = await startNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after tapping Image button")
            return nil
        }
        return imageFormNode
    }

    // MARK: - Node shape

    func testAutomationImageNodeHasCorrectName() async throws {
        guard let node = await navigateToImageForm() else { return }
        XCTAssertEqual(expectedNodeName, node.name)
    }

    func testAutomationImageNodeHasThreeCollectors() async throws {
        guard let node = await navigateToImageForm() else { return }
        XCTAssertEqual(3, node.collectors.count)
        XCTAssertTrue(node.collectors[labelIndex] is LabelCollector)
        XCTAssertTrue(node.collectors[imageIndex] is ImageCollector)
        XCTAssertTrue(node.collectors[submitIndex] is SubmitCollector)
    }

    // MARK: - ImageCollector properties

    func testImageCollectorHasCorrectKey() async throws {
        guard let node = await navigateToImageForm() else { return }
        let collector = node.collectors[imageIndex] as! ImageCollector
        XCTAssertEqual(expectedImageKey, collector.key)
    }

    func testImageCollectorHasCorrectDescription() async throws {
        guard let node = await navigateToImageForm() else { return }
        let collector = node.collectors[imageIndex] as! ImageCollector
        XCTAssertEqual(expectedImageDescription, collector.description)
    }

    func testImageCollectorHasCorrectImageUrl() async throws {
        guard let node = await navigateToImageForm() else { return }
        let collector = node.collectors[imageIndex] as! ImageCollector
        XCTAssertEqual(expectedImageUrl, collector.imageUrl)
    }

    func testImageCollectorHasCorrectHyperlinkUrl() async throws {
        guard let node = await navigateToImageForm() else { return }
        let collector = node.collectors[imageIndex] as! ImageCollector
        XCTAssertEqual(expectedHyperlinkUrl, collector.hyperlinkUrl)
    }

    func testImageCollectorIdReturnsKey() async throws {
        guard let node = await navigateToImageForm() else { return }
        let collector = node.collectors[imageIndex] as! ImageCollector
        XCTAssertEqual(collector.key, collector.id)
    }

    // MARK: - LabelCollector rich content

    func testLabelCollectorRichContentContainsTitle() async throws {
        guard let node = await navigateToImageForm() else { return }
        let label = node.collectors[labelIndex] as! LabelCollector
        XCTAssertNotNil(label.richContent)
        XCTAssertEqual("Image Collector Test", label.richContent?.content)
    }

    // MARK: - Flow navigation

    func testContinueReturnsToSelectTestForm() async throws {
        guard let node = await navigateToImageForm() else { return }
        XCTAssertEqual(expectedNodeName, node.name)

        (node.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after Continue")
            return
        }
        XCTAssertEqual("Select Test Form", nextNode.name)
    }
}
