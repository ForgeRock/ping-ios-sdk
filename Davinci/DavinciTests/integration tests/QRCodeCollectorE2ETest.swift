//
//  QRCodeCollectorE2ETest.swift
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

/// E2E tests for QRCodeCollector — DaVinci QR_CODE-type form field (SDKS-4680).
///
/// The test flow starts with a "Select Test Form" that presents a FlowCollector "QRCode" button.
/// Tapping it transitions to the "Automation - QR Code" showForm node which contains:
///
///   index 0 — LabelCollector  (key "title-text", richContent "QR Code Collector Test")
///   index 1 — QRCodeCollector (key "qr-code", content as raw Base64 data URI, non-empty fallbackText)
///   index 2 — SubmitCollector (key "submit", label "Continue")
///
/// The ERROR_DISPLAY field returned by the form has no registered collector type and is
/// intentionally dropped by the CollectorFactory, hence 3 collectors for 4 fields.
///
/// Tapping Continue loops back to the Select Test Form.
///
class QRCodeCollectorE2ETest: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    // MARK: - Index constants

    private let qrCodeButtonIndex = 2  // FlowCollector "QRCode" on Select Test Form (0 = Metadata, 1 = Image)
    private let labelIndex = 0         // LabelCollector (title-text) on Automation - QR Code
    private let qrCodeIndex = 1        // QRCodeCollector (qr-code) on Automation - QR Code
    private let submitIndex = 2        // SubmitCollector "Continue" on Automation - QR Code

    // MARK: - Expected values

    private let expectedNodeName = "Automation - QR Code"
    private let expectedQRCodeKey = "qr-code"
    private let expectedLabelRichContent = "QR Code Collector Test"
    private let expectedFallbackText =
        "If you can't scan the QR code, use the following link:https://www.pingidentity.com/en.html"
    private let expectedContentPrefix = "data:image/png;base64,"

    override func setUp() async throws {
        self.configFileName = "DaVinci-e2e-config"
        try await super.setUp()

        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.acrValues = self.config.imageAcrValues
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }

        await daVinci.daVinciUser()?.logout()
    }

    // MARK: - Helper

    /// Navigates from start() to the "Automation - QR Code" form node.
    private func navigateToQRCodeForm() async -> ContinueNode? {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return nil
        }
        XCTAssertEqual("Select Test Form", startNode.name)
        guard let qrCodeButton = startNode.collectors[qrCodeButtonIndex] as? FlowCollector else {
            XCTFail("Expected FlowCollector at index \(qrCodeButtonIndex)")
            return nil
        }
        XCTAssertEqual("QRCode", qrCodeButton.label)
        qrCodeButton.value = "click"

        guard let qrCodeFormNode = await startNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after tapping QRCode button")
            return nil
        }
        return qrCodeFormNode
    }

    // MARK: - Node shape

    func testAutomationQRCodeNodeHasCorrectName() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        XCTAssertEqual(expectedNodeName, node.name)
    }

    func testAutomationQRCodeNodeHasThreeCollectors() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        // 4 fields in the form JSON; the unregistered ERROR_DISPLAY type is dropped
        XCTAssertEqual(3, node.collectors.count)
        XCTAssertTrue(node.collectors[labelIndex] is LabelCollector)
        XCTAssertTrue(node.collectors[qrCodeIndex] is QRCodeCollector)
        XCTAssertTrue(node.collectors[submitIndex] is SubmitCollector)
    }

    // MARK: - QRCodeCollector properties

    func testQRCodeCollectorIsInstantiatedForQR_CODEType() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        XCTAssertTrue(node.collectors[qrCodeIndex] is QRCodeCollector)
    }

    func testQRCodeCollectorHasCorrectKey() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector
        XCTAssertEqual(expectedQRCodeKey, collector.key)
    }

    func testQRCodeCollectorContentIsTheRawDataUri() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector

        // SDKS-5299: content must retain the raw data URI exactly as received
        XCTAssertTrue(
            collector.content.hasPrefix(expectedContentPrefix),
            "Expected content to start with '\(expectedContentPrefix)', was: \(collector.content.prefix(60))"
        )
    }

    func testQRCodeCollectorHasCorrectFallbackText() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector
        XCTAssertEqual(expectedFallbackText, collector.fallbackText)
        XCTAssertFalse(collector.fallbackText.isEmpty)
    }

    func testQRCodeCollectorIdReturnsKey() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector
        XCTAssertEqual(collector.key, collector.id)
    }

    func testQRCodeCollectorImageDataDecodes() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector

        let imageData = collector.imageData
        XCTAssertNotNil(imageData, "imageData must decode the valid Base64 PNG data URI")
        XCTAssertTrue((imageData?.isEmpty == false), "Decoded image data must be non-empty")
    }

    // MARK: - payload

    func testQRCodeCollectorDoesNotContributeToFormPayload() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let collector = node.collectors[qrCodeIndex] as! QRCodeCollector

        // A nil payload means the QR_CODE field is omitted from the form POST
        XCTAssertNil(collector.payload())
    }

    // MARK: - Flow navigation

    func testSubmittingQRCodeFormLoopsBackToSelectTestForm() async throws {
        guard var node = await navigateToQRCodeForm() else { return }
        XCTAssertEqual(expectedNodeName, node.name)

        // Submit without interacting with the QR code — submission must succeed
        (node.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after Continue")
            return
        }
        XCTAssertEqual("Select Test Form", nextNode.name)
    }

    // MARK: - LabelCollector rich content

    func testLabelCollectorRichContentContainsTitle() async throws {
        guard let node = await navigateToQRCodeForm() else { return }
        let label = node.collectors[labelIndex] as! LabelCollector
        XCTAssertNotNil(label.richContent)
        XCTAssertEqual(expectedLabelRichContent, label.richContent?.content)
    }
}
