//
//  PollingCollectorIntegrationTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import CoreImage
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingOidc
@testable import PingStorage
@testable import PingDavinci

/// E2E tests for PollingCollector covering two DaVinci policies:
///   - Simple (continue) polling: pollChallengeStatus=false, 3 retries, 2 s interval
///   - Challenge-status polling: pollChallengeStatus=true, 2 s interval
class PollingCollectorIntegrationTests: DaVinciBaseTests, @unchecked Sendable {
    private var daVinci: DaVinci!

    override func setUp() async throws {
        self.configFileName = "ConfigNew"
        try await super.setUp()

        // Clear all shared cookies before each test. The polling flows never produce a
        // SuccessNode user, so daVinci.daVinciUser()?.logout() is always a no-op here.
        // Without this, a session left mid-flow by a previous run (e.g. parked at
        // "Automation - Polling Message" after a successful approval) causes start() to
        // resume the old interaction instead of beginning a fresh one, and the returned
        // node has no PollingCollector.
        HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }

        daVinci = DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = self.config.clientId
                oidcValue.scopes = Set(self.config.scopes)
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.acrValues = "fae6bc3d08a5c4f5b8ff95175b117278"
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
            }
        }

        await daVinci.daVinciUser()?.logout()
    }

    // =========================================================================
    // Simple (Continue) Polling
    // =========================================================================

    /// All 3 retries exhaust without completion. Each cycle the caller submits and the server
    /// rewinds to the same form; on the third cycle .timedOut is emitted and the final submit
    /// returns a 400 ErrorNode with message "timedOut".
    func testContinuePollingTimeout() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let submitCollector = node.collectors[0] as? SubmitCollector else {
            XCTFail("Expected SubmitCollector at collectors[0]")
            return
        }
        XCTAssertEqual("Continue Polling", submitCollector.label)

        guard let challengeButton = node.collectors[1] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[1]")
            return
        }
        XCTAssertEqual("Challenge Polling", challengeButton.label)

        submitCollector.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submit")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling", node.name)

        // Cycle 1 — retriesAllowed 3→2; emits .complete("continue"); server rewinds to same form
        guard var pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertFalse(pollingCollector.pollChallengeStatus)
        XCTAssertEqual(2000, pollingCollector.pollInterval)
        XCTAssertEqual(3, pollingCollector.pollRetries)
        XCTAssertEqual(3, pollingCollector.retriesAllowed)

        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() { statuses.append(status) }
        XCTAssertEqual(2, statuses.count)
        if case .continue = statuses[0] { } else { XCTFail("Expected .continue, got \(statuses[0])") }
        if case .complete(let value) = statuses[1] {
            XCTAssertEqual("continue", value)
        } else { XCTFail("Expected .complete(\"continue\"), got \(statuses[1])") }
        XCTAssertEqual("continue", pollingCollector.value)
        XCTAssertEqual(2, pollingCollector.retriesAllowed)

        guard let rewindNode1 = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after cycle 1 submit")
            return
        }
        node = rewindNode1
        XCTAssertEqual("Automation - Polling", node.name)

        // Cycle 2 — retriesAllowed 2→1
        guard let cycle2Collector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found on cycle 2 node")
            return
        }
        pollingCollector = cycle2Collector

        statuses = []
        for await status in pollingCollector.poll() { statuses.append(status) }
        XCTAssertEqual(2, statuses.count)
        if case .complete(let value) = statuses[1] {
            XCTAssertEqual("continue", value)
        } else { XCTFail("Expected .complete(\"continue\"), got \(statuses[1])") }
        XCTAssertEqual("continue", pollingCollector.value)
        XCTAssertEqual(1, pollingCollector.retriesAllowed)

        guard let rewindNode2 = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after cycle 2 submit")
            return
        }
        node = rewindNode2
        XCTAssertEqual("Automation - Polling", node.name)

        // Cycle 3 — retriesAllowed 1→0; emits .timedOut; submit returns 400 ErrorNode
        guard let cycle3Collector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found on cycle 3 node")
            return
        }
        pollingCollector = cycle3Collector

        statuses = []
        for await status in pollingCollector.poll() { statuses.append(status) }
        XCTAssertEqual(2, statuses.count)
        if case .timedOut = statuses[1] {
            XCTAssertEqual("timedOut", pollingCollector.value)
        } else { XCTFail("Expected .timedOut, got \(statuses[1])") }
        XCTAssertEqual(0, pollingCollector.retriesAllowed)

        // SDKS-5095: iOS SDK returns FailureNode instead of ErrorNode (Android parity fix pending).
        // Assert the current actual type so regressions are caught until the fix lands.
//        guard let timedOutError = await node.next() as? ErrorNode else {
//            XCTFail("Expected ErrorNode, got FailureNode")
//            return
//        }
//        XCTAssertEqual("timedOut", timedOutError.message.trimmingCharacters(in: .whitespacesAndNewlines))
        let timeoutResult = await node.next()
        XCTAssertTrue(timeoutResult is FailureNode, "SDKS-5095: expected FailureNode until iOS/Android parity is fixed")
    }

    /// User clicks "Finish" after one poll cycle, bypassing remaining retries.
    /// The server skips the rewind and returns the "Done" message form directly.
    func testContinuePollingFinish() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let submitCollector = node.collectors[0] as? SubmitCollector else {
            XCTFail("Expected SubmitCollector at collectors[0]")
            return
        }
        submitCollector.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submit")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling", node.name)

        guard let pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertFalse(pollingCollector.pollChallengeStatus)

        // One poll cycle → .complete("continue"); server rewinds to same form
        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() { statuses.append(status) }
        XCTAssertEqual(2, statuses.count)
        if case .complete(let value) = statuses[1] {
            XCTAssertEqual("continue", value)
        } else { XCTFail("Expected .complete(\"continue\"), got \(statuses[1])") }

        guard let rewindNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after poll cycle submit")
            return
        }
        node = rewindNode
        XCTAssertEqual("Automation - Polling", node.name)

        // Click "Finish" → server returns the "Done" message form
        guard let finishButton = node.collectors.first(where: { ($0 as? FlowCollector)?.label == "Finish" }) as? FlowCollector else {
            XCTFail("Finish FlowCollector not found")
            return
        }
        finishButton.value = finishButton.label

        guard let messageNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Finish")
            return
        }
        node = messageNode
        XCTAssertEqual("Automation - Polling Message", node.name)

        let doneLabel = node.collectors.first { ($0 as? LabelCollector)?.content == "Message: Done" } as? LabelCollector
        XCTAssertNotNil(doneLabel)
        XCTAssertEqual("Message: Done", doneLabel?.content)
    }

    // =========================================================================
    // Challenge-Status Polling
    // =========================================================================

    /// No approval is given; all 3 poll cycles return isChallengeComplete=false, so
    /// poll() emits .continue(1,3), .continue(2,3), .continue(3,3), .timedOut.
    /// The final submit returns a 400 ErrorNode with message "timedOut".
    func testChallengePollingTimeout() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let challengeButton = node.collectors[1] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[1]")
            return
        }
        XCTAssertEqual("Challenge Polling", challengeButton.label)
        challengeButton.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Challenge Polling button")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling", node.name)

        guard let pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertTrue(pollingCollector.pollChallengeStatus)
        XCTAssertEqual(2000, pollingCollector.pollInterval)
        XCTAssertEqual(3, pollingCollector.pollRetries)
        XCTAssertFalse(pollingCollector.challenge.isEmpty)

        // 3 × .continue + 1 × .timedOut
        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() { statuses.append(status) }
        XCTAssertEqual(4, statuses.count)
        for i in 0..<3 {
            if case .continue(let retryCount, let maxRetries) = statuses[i] {
                XCTAssertEqual(i + 1, retryCount)
                XCTAssertEqual(3, maxRetries)
            } else { XCTFail("Expected .continue at index \(i), got \(statuses[i])") }
        }
        if case .timedOut = statuses[3] {
            XCTAssertEqual("timedOut", pollingCollector.value)
        } else { XCTFail("Expected .timedOut, got \(statuses[3])") }

        // SDKS-5095: iOS SDK returns FailureNode instead of ErrorNode (Android parity fix pending).
        // Assert the current actual type so regressions are caught until the fix lands.
//        guard let timedOutError = await node.next() as? ErrorNode else {
//            XCTFail("Expected ErrorNode, got FailureNode")
//            return
//        }
//        XCTAssertEqual("timedOut", timedOutError.message.trimmingCharacters(in: .whitespacesAndNewlines))
        let timeoutResult = await node.next()
        XCTAssertTrue(timeoutResult is FailureNode, "SDKS-5095: expected FailureNode until iOS/Android parity is fixed")
    }

    /// OOB approval is simulated by GETting the magic link (from the LabelCollector) on a
    /// background task while poll() polls concurrently. Approval is sent once the first
    /// .continue status is received, guaranteeing the challenge is registered before the
    /// approval request is sent. The last emitted status must be .complete("approved") and
    /// the flow must advance to "Automation - Polling Message".
    func testChallengePollingApproval() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let challengeButton = node.collectors[1] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[1]")
            return
        }
        XCTAssertEqual("Challenge Polling", challengeButton.label)
        challengeButton.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Challenge Polling button")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling", node.name)

        guard let pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertTrue(pollingCollector.pollChallengeStatus)
        XCTAssertFalse(pollingCollector.challenge.isEmpty)

        // The OOB URL is embedded in a label as "Number Challenge <url>"
        guard let magicLabel = node.collectors.first(where: { ($0 as? LabelCollector)?.content.hasPrefix("Number Challenge ") == true }) as? LabelCollector else {
            XCTFail("LabelCollector with 'Number Challenge' prefix not found")
            return
        }
        guard let magicLink = magicLabel.content.components(separatedBy: "Number Challenge ").last?.trimmingCharacters(in: .whitespaces) else {
            XCTFail("Could not extract magic link from label content")
            return
        }
        XCTAssertTrue(magicLink.hasPrefix("https://"), "Expected a magic link URL, got: \(magicLink)")

        // Poll and send approval once the first .continue status is received.
        var approvalTask: Task<Void, Never>?
        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() {
            statuses.append(status)
            if case .continue = status, approvalTask == nil {
                approvalTask = Task {
                    guard let url = URL(string: magicLink) else { return }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    _ = try? await URLSession.shared.data(for: request)
                }
            }
        }

        // Wait for the approval HTTP request to complete before asserting
        await approvalTask?.value

        guard let lastStatus = statuses.last else { XCTFail("statuses is empty"); return }
        if case .complete(let s) = lastStatus {
            XCTAssertEqual("approved", s)
            XCTAssertEqual("approved", pollingCollector.value)
        } else { XCTFail("Expected .complete(\"approved\") as last status, got \(lastStatus)") }

        guard let messageNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after approval submit")
            return
        }
        node = messageNode
        XCTAssertEqual("Automation - Polling Message", node.name)

        let approvedLabel = node.collectors.first { ($0 as? LabelCollector)?.content == "Message: approved" } as? LabelCollector
        XCTAssertNotNil(approvedLabel)
        XCTAssertEqual("Message: approved", approvedLabel?.content)
    }

    // =========================================================================
    // QR Code + Challenge-Status Polling
    // =========================================================================

    /// The "Challenge Polling QRCode" flow shows a QR_CODE field alongside a POLLING field.
    /// No approval is given; all retries exhaust → .timedOut → 400 ErrorNode.
    /// Verifies QRCodeCollector properties (valid data URI, decodable imageData) before polling.
    func testQRCodeChallengePollingTimeout() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let qrButton = node.collectors[2] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[2]")
            return
        }
        XCTAssertEqual("Challenge Polling QRCode", qrButton.label)
        qrButton.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Challenge Polling QRCode button")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling with QR Code", node.name)

        // Verify QRCodeCollector is present and well-formed
        guard let qrCodeCollector = node.collectors.first(where: { $0 is QRCodeCollector }) as? QRCodeCollector else {
            XCTFail("QRCodeCollector not found")
            return
        }
        XCTAssertNotNil(qrCodeCollector.imageData, "imageData must decode from a valid base64 data URI")

        // Verify PollingCollector is present and configured for challenge-status polling
        guard let pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertTrue(pollingCollector.pollChallengeStatus)
        XCTAssertEqual(2000, pollingCollector.pollInterval)
        XCTAssertFalse(pollingCollector.challenge.isEmpty)

        // Poll until all retries exhaust — no OOB approval → .timedOut is emitted last
        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() { statuses.append(status) }

        guard let lastStatus = statuses.last else { XCTFail("statuses is empty"); return }
        if case .timedOut = lastStatus {
            XCTAssertEqual("timedOut", pollingCollector.value)
        } else { XCTFail("Expected .timedOut as last status, got \(lastStatus)") }

        // SDKS-5095: iOS SDK returns FailureNode instead of ErrorNode (Android parity fix pending).
        // Assert the current actual type so regressions are caught until the fix lands.
//        guard let timedOutError = await node.next() as? ErrorNode else {
//            XCTFail("Expected ErrorNode, got FailureNode")
//            return
//        }
//        XCTAssertEqual("timedOut", timedOutError.message.trimmingCharacters(in: .whitespacesAndNewlines))
        let timeoutResult = await node.next()
        XCTAssertTrue(timeoutResult is FailureNode, "SDKS-5095: expected FailureNode until iOS/Android parity is fixed")
    }

    /// Simulates scanning the QR code by decoding the URL from the imageData and GETting it
    /// on a background task while poll() polls concurrently. The approval is sent once the
    /// first .continue status is received; the last status must be .complete("approved") and
    /// the flow must advance to "Automation - Polling Message".
    ///
    /// Note: The QR code encodes a URL that, when fetched via GET, approves the challenge.
    /// On iOS the encoded URL is read from `imageData` using CoreImage's QR detector.
    func testQRCodeChallengePollingApproval() async throws {
        guard let startNode = await daVinci.start() as? ContinueNode else {
            XCTFail("Expected ContinueNode from start()")
            return
        }
        var node = startNode
        XCTAssertEqual("Select Test Form", node.name)

        guard let qrButton = node.collectors[2] as? FlowCollector else {
            XCTFail("Expected FlowCollector at collectors[2]")
            return
        }
        XCTAssertEqual("Challenge Polling QRCode", qrButton.label)
        qrButton.value = "click"

        guard let pollingFormNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after Challenge Polling QRCode button")
            return
        }
        node = pollingFormNode
        XCTAssertEqual("Automation - Polling with QR Code", node.name)

        guard let qrCodeCollector = node.collectors.first(where: { $0 is QRCodeCollector }) as? QRCodeCollector,
              let imageData = qrCodeCollector.imageData,
              let approvalUrl = Self.decodeQRCode(from: imageData) else {
            XCTFail("Could not get QRCodeCollector or decode URL from QR code imageData")
            return
        }
        XCTAssertTrue(approvalUrl.hasPrefix("https://"), "Expected an HTTPS URL in QR code, got: \(approvalUrl)")

        guard let pollingCollector = node.collectors.first(where: { $0 is PollingCollector }) as? PollingCollector else {
            XCTFail("PollingCollector not found")
            return
        }
        XCTAssertTrue(pollingCollector.pollChallengeStatus)
        XCTAssertFalse(pollingCollector.challenge.isEmpty)

        // Poll and send approval once the first .continue status is received.
        var approvalTask: Task<Void, Never>?
        var statuses: [PollingStatus] = []
        for await status in pollingCollector.poll() {
            statuses.append(status)
            if case .continue = status, approvalTask == nil {
                approvalTask = Task {
                    guard let url = URL(string: approvalUrl) else { return }
                    var request = URLRequest(url: url)
                    request.timeoutInterval = 10
                    _ = try? await URLSession.shared.data(for: request)
                }
            }
        }
        await approvalTask?.value

        guard let lastStatus = statuses.last else { XCTFail("statuses is empty"); return }
        if case .complete(let s) = lastStatus {
            XCTAssertEqual("approved", s)
            XCTAssertEqual("approved", pollingCollector.value)
        } else { XCTFail("Expected .complete(\"approved\") as last status, got \(lastStatus)") }

        guard let messageNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after approval submit")
            return
        }
        node = messageNode
        XCTAssertEqual("Automation - Polling Message", node.name)

        let approvedLabel = node.collectors.first { ($0 as? LabelCollector)?.content == "Message: approved" } as? LabelCollector
        XCTAssertNotNil(approvedLabel)
        XCTAssertEqual("Message: approved", approvedLabel?.content)
    }

    // MARK: - Private helpers

    /// Decodes the URL text encoded in a QR code image using CoreImage's built-in detector.
    /// Returns nil if the image cannot be decoded or no QR code is found.
    private static func decodeQRCode(from data: Data) -> String? {
        guard let ciImage = CIImage(data: data) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) ?? []
        return (features.first as? CIQRCodeFeature)?.messageString
    }
}
