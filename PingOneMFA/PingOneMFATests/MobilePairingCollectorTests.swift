//
//  MobilePairingCollectorTests.swift
//  PingOneMFATests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//

import XCTest
import PingDavinciPlugin
@testable import PingOneMFA

private actor PairingProbe {
    private(set) var callCount = 0
    private var continuations: [CheckedContinuation<Void, Error>] = []

    func pair() async throws {
        callCount += 1
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func succeedAll() {
        continuations.forEach { $0.resume() }
        continuations.removeAll()
    }

    func failAll(with error: Error) {
        continuations.forEach { $0.resume(throwing: error) }
        continuations.removeAll()
    }
}

private struct ProbePairingClient: MobilePairingClient {
    let probe: PairingProbe

    func pair(pairingKey: String) async throws {
        try await probe.pair()
    }
}

final class MobilePairingCollectorTests: XCTestCase {
    private let json: [String: Any] = [
        "type": "MOBILE_PAIRING",
        "key": "mobilePairing",
        "pairingKey": "pairing-key"
    ]

    func testParsesInputAndUsesKeyAsId() {
        let collector = MobilePairingCollector(with: json)
        XCTAssertEqual(collector.type, "MOBILE_PAIRING")
        XCTAssertEqual(collector.key, "mobilePairing")
        XCTAssertEqual(collector.pairingKey, "pairing-key")
        XCTAssertEqual(collector.id, "mobilePairing")
    }

    func testMissingInputDefaultsToEmptyStrings() {
        let collector = MobilePairingCollector(with: [:])
        XCTAssertEqual(collector.type, "")
        XCTAssertEqual(collector.key, "")
        XCTAssertEqual(collector.pairingKey, "")
    }

    func testInitialContract() {
        let collector = MobilePairingCollector(with: json)
        XCTAssertNil(collector.payload())
        XCTAssertNil(collector.anyPayload())
        XCTAssertEqual(collector.eventType(), "action")
        XCTAssertEqual(collector.validate(), [.required])
        XCTAssertFalse(collector is any ActionKeyProvider)
    }

    func testInitializeDoesNotAcceptServerEchoedOutcome() {
        let collector = MobilePairingCollector(with: json)
        collector.initialize(with: ["status": "CLAIMED"])
        XCTAssertNil(collector.payload())
    }

    func testSuccessfulPairingStoresClaimedOutcome() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        await probe.succeedAll()

        guard case .success = await collection.value else {
            return XCTFail("Expected pairing success")
        }
        XCTAssertEqual(collector.payload()?["status"] as? String, "CLAIMED")
        XCTAssertTrue(collector.validate().isEmpty)
    }

    func testNativeErrorUsesFirstNumericCodeAndMessage() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        let native = NSError(domain: "PingOne", code: 10005, userInfo: [NSLocalizedDescriptionKey: "Invalid pairing key"])
        await probe.failAll(with: PingOneMFAError(native))

        guard case .failure = await collection.value else {
            return XCTFail("Expected pairing failure")
        }
        let error = collector.payload()?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? String, "10005")
        XCTAssertEqual(error?["message"] as? String, "Code=10005 Invalid pairing key")
    }

    func testUnexpectedErrorUsesInternalErrorCode() async {
        struct Unexpected: LocalizedError {
            var errorDescription: String? { "Unexpected failure" }
        }
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        await probe.failAll(with: Unexpected())

        guard case .failure = await collection.value else {
            return XCTFail("Expected pairing failure")
        }
        let error = collector.payload()?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? String, "INTERNAL_ERROR")
        XCTAssertEqual(error?["message"] as? String, "Unexpected failure")
    }

    func testCancelBeforeCollectSkipsNativePairing() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        collector.cancel()
        guard case .failure = await collector.collect() else {
            return XCTFail("Expected cancellation")
        }
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 0)
        assertError(collector.payload(), code: "USER_CANCELLED", message: "User canceled the pairing flow")
    }

    func testCustomCancellationMessage() {
        let collector = MobilePairingCollector(with: json)
        collector.cancel(message: "Pairing dismissed")
        assertError(collector.payload(), code: "USER_CANCELLED", message: "Pairing dismissed")
    }

    func testCancellationWinsOverLateSuccess() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        collector.cancel()
        await probe.succeedAll()
        _ = await collection.value
        assertError(collector.payload(), code: "USER_CANCELLED", message: "User canceled the pairing flow")
    }

    func testCancellationWinsOverLateFailure() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        collector.cancel()
        let native = NSError(domain: "PingOne", code: 10013, userInfo: [NSLocalizedDescriptionKey: "Already claimed"])
        await probe.failAll(with: PingOneMFAError(native))
        _ = await collection.value
        assertError(collector.payload(), code: "USER_CANCELLED", message: "User canceled the pairing flow")
    }

    func testConcurrentCollectCallsPairOnce() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        async let first = collector.collect()
        async let second = collector.collect()
        await waitForCallCount(1, probe: probe)
        await probe.succeedAll()
        _ = await (first, second)
        let callCount = await probe.callCount
        XCTAssertEqual(callCount, 1)
    }

    func testCloseClearsAndInvalidatesLateCompletion() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        collector.close()
        await probe.succeedAll()
        _ = await collection.value
        XCTAssertNil(collector.payload())
        XCTAssertEqual(collector.validate(), [.required])
    }

    func testCloseAfterCompletedOutcomeRestoresRequiredValidation() async {
        let probe = PairingProbe()
        let collector = MobilePairingCollector(with: json, client: ProbePairingClient(probe: probe))
        let collection = Task { await collector.collect() }
        await waitForCallCount(1, probe: probe)
        await probe.succeedAll()
        _ = await collection.value

        collector.close()

        XCTAssertNil(collector.payload())
        XCTAssertEqual(collector.validate(), [.required])
    }

    private func waitForCallCount(_ expected: Int, probe: PairingProbe) async {
        for _ in 0..<100 {
            if await probe.callCount == expected {
                return
            }
            await Task.yield()
        }
        XCTFail("Expected pairing client call count \(expected)")
    }

    private func assertError(_ payload: [String: Any]?, code: String, message: String, file: StaticString = #filePath, line: UInt = #line) {
        let error = payload?["error"] as? [String: Any]
        XCTAssertEqual(error?["code"] as? String, code, file: file, line: line)
        XCTAssertEqual(error?["message"] as? String, message, file: file, line: line)
    }
}
