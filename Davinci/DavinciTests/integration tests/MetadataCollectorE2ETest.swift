//
//  MetadataCollectorE2ETest.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingDavinciPlugin
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

/// E2E tests for MetadataCollector — DaVinci SDK Integrator connector
/// (`exchangeCustomMetadata` capability).
///
/// The test flow starts with a "Select Test Form" that presents a "Metadata" submit button.
/// Tapping it transitions to an `exchangeCustomMetadata` node that returns a single METADATA
/// field with key "sdkMetadata" and payload {"testkey":"testValue"}.
/// After the SDK submits its response the flow transitions to an "Automation - Message" form
/// which echoes the submitted value back to the client, confirming what DaVinci received.
class MetadataCollectorE2ETest: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    // MARK: - Index constants

    private let metadataButtonIndex = 0    // SubmitCollector "Metadata" on Select Test Form
    private let metadataCollectorIndex = 0 // MetadataCollector on exchangeCustomMetadata node
    private let labelIndex = 0             // LabelCollector (echoed value) on Automation - Message
    private let submitIndex = 1            // SubmitCollector "Continue" on Automation - Message

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
                oidcValue.acrValues = self.config.metadataAcrValues
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }

        await daVinci.daVinciUser()?.logout()
    }

    // MARK: - Helper

    /// Navigates from start() to the exchangeCustomMetadata node.
    private func navigateToMetadataNode() async -> ContinueNode? {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return nil
        }
        XCTAssertEqual("Select Test Form", startNode.name)
        guard let metadataButton = startNode.collectors[metadataButtonIndex] as? SubmitCollector else {
            XCTFail("Expected SubmitCollector at index \(metadataButtonIndex)")
            return nil
        }
        XCTAssertEqual("Metadata", metadataButton.label)
        metadataButton.value = "click"

        guard let metadataNode = await startNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after tapping Metadata button")
            return nil
        }
        return metadataNode
    }

    // MARK: - Collector shape and payload

    func testMetadataCollectorIsPresentWithCorrectShape() async throws {
        guard let node = await navigateToMetadataNode() else { return }

        XCTAssertEqual(1, node.collectors.count)
        XCTAssertTrue(node.collectors[metadataCollectorIndex] is MetadataCollector)

        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector
        XCTAssertEqual("sdkMetadata", collector.key)
        XCTAssertEqual("METADATA", collector.type)
        XCTAssertEqual("testValue", collector.metadata["testkey"] as? String)
    }

    func testMetadataCollectorPayloadIsNilBeforeSetResultOrSetError() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector
        XCTAssertNil(collector.payload())
    }

    // MARK: - Validation

    func testValidateRequiresResponseBeforeSubmit() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        let errors = collector.validate()
        XCTAssertFalse(errors.isEmpty)
        XCTAssertEqual([ValidationError.required], errors)
    }

    func testValidatePassesAfterSetResult() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setResult(["status": "success"])
        XCTAssertTrue(collector.validate().isEmpty)
    }

    func testValidatePassesAfterSetError() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setError(code: "100", message: "An error occurred")
        XCTAssertTrue(collector.validate().isEmpty)
    }

    // MARK: - Success path — setResult

    func testSetResultAdvancesFlowToSuccessBranch() async throws {
        guard var node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setResult(["status": "success"])

        guard let messageNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Automation - Message) after setResult submit")
            return
        }
        node = messageNode
        XCTAssertEqual("Automation - Message", node.name)

        let label = node.collectors[labelIndex] as! LabelCollector
        XCTAssertTrue(
            label.content.contains("success"),
            "Expected echoed label to contain 'success', was: \(label.content)"
        )

        // Continue back to the Select Test Form — confirms the success branch completed
        (node.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let selectNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after Continue")
            return
        }
        XCTAssertEqual("Select Test Form", selectNode.name)
    }

    func testSetResultPayloadContainsProvidedData() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setResult(["status": "success"])

        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual("success", payload?["status"] as? String)
    }

    // MARK: - Error path — setError

    func testSetErrorAdvancesFlowToErrorBranch() async throws {
        guard var node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setError(code: "100", message: "An error occurred")

        guard let messageNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Automation - Message) after setError submit")
            return
        }
        node = messageNode
        XCTAssertEqual("Automation - Message", node.name)

        let label = node.collectors[labelIndex] as! LabelCollector
        XCTAssertTrue(
            label.content.contains("100"),
            "Expected echoed label to contain error code '100', was: \(label.content)"
        )
        XCTAssertTrue(
            label.content.contains("An error occurred"),
            "Expected echoed label to contain error message, was: \(label.content)"
        )

        // Continue back to Select Test Form — confirms the error branch completed
        (node.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let selectNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after Continue")
            return
        }
        XCTAssertEqual("Select Test Form", selectNode.name)
    }

    func testSetErrorPayloadContainsStructuredErrorEnvelope() async throws {
        guard let node = await navigateToMetadataNode() else { return }
        let collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setError(code: "100", message: "An error occurred")

        let payload = collector.payload()
        XCTAssertNotNil(payload)

        let error = payload?["error"] as? [String: Any]
        XCTAssertNotNil(error)
        XCTAssertEqual("100", error?["code"] as? String)
        XCTAssertEqual("An error occurred", error?["message"] as? String)
    }

    // MARK: - Repeated iterations (loop)

    func testMetadataFlowCanBeTraversedTwiceInTheSameSession() async throws {
        // First iteration — success
        guard var node = await navigateToMetadataNode() else { return }
        var collector = node.collectors[metadataCollectorIndex] as! MetadataCollector

        collector.setResult(["status": "success"])

        guard let messageNode1 = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Automation - Message) on iteration 1")
            return
        }
        node = messageNode1
        XCTAssertEqual("Automation - Message", node.name)

        (node.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let selectNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after iteration 1")
            return
        }
        XCTAssertEqual("Select Test Form", selectNode.name)

        // Second iteration — error; the new collector must be independent of the first
        (selectNode.collectors[metadataButtonIndex] as! SubmitCollector).value = "click"
        guard let node2 = await selectNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (exchangeCustomMetadata) on iteration 2")
            return
        }

        XCTAssertEqual(1, node2.collectors.count)
        XCTAssertTrue(node2.collectors[metadataCollectorIndex] is MetadataCollector)

        collector = node2.collectors[metadataCollectorIndex] as! MetadataCollector
        // Payload from the previous iteration must not carry over
        XCTAssertNil(collector.payload())
        XCTAssertEqual("testValue", collector.metadata["testkey"] as? String)

        collector.setError(code: "100", message: "An error occurred")

        guard let messageNode2 = await node2.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Automation - Message) on iteration 2")
            return
        }
        XCTAssertEqual("Automation - Message", messageNode2.name)

        let label = messageNode2.collectors[labelIndex] as! LabelCollector
        XCTAssertTrue(label.content.contains("100"))

        (messageNode2.collectors[submitIndex] as! SubmitCollector).value = "click"
        guard let selectNode2 = await messageNode2.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Select Test Form) after iteration 2")
            return
        }
        XCTAssertEqual("Select Test Form", selectNode2.name)
    }
}
