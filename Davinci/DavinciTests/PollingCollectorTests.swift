//
//  PollingCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci
@testable import PingOrchestrate
@testable import PingNetwork
import PingDavinciPlugin

class PollingCollectorTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultInitialization() {
        let collector = PollingCollector(with: [:])

        XCTAssertEqual(collector.pollInterval, 2000)
        XCTAssertEqual(collector.pollRetries, 60)
        XCTAssertFalse(collector.pollChallengeStatus)
        XCTAssertEqual(collector.challenge, "")
        XCTAssertEqual(collector.retriesAllowed, 60)
        XCTAssertEqual(collector.value, "")
    }

    func testCustomInitialization() {
        let json: [String: Any] = [
            "type": "POLLING",
            "key": "polling-field",
            "pollInterval": "3000",
            "pollRetries": "10",
            "pollChallengeStatus": true,
            "challenge": "abc123"
        ]

        let collector = PollingCollector(with: json)

        XCTAssertEqual(collector.pollInterval, 3000)
        XCTAssertEqual(collector.pollRetries, 10)
        XCTAssertTrue(collector.pollChallengeStatus)
        XCTAssertEqual(collector.challenge, "abc123")
        XCTAssertEqual(collector.retriesAllowed, 10)
    }

    func testRetriesAllowedInitializedFromPollRetries() {
        let json: [String: Any] = ["pollRetries": "5"]
        let collector = PollingCollector(with: json)
        XCTAssertEqual(collector.retriesAllowed, 5)
    }

    func testInvalidPollRetriesFallsBackToDefault() {
        let json: [String: Any] = ["pollRetries": "not-a-number"]
        let collector = PollingCollector(with: json)
        XCTAssertEqual(collector.retriesAllowed, 60)
    }

    func testPollRetriesAndIntervalAsNumbers() {
        // Server may send numeric values without quotes (e.g. pollRetries: 3, pollInterval: 2000).
        let json: [String: Any] = ["pollRetries": 3, "pollInterval": 2000]
        let collector = PollingCollector(with: json)
        XCTAssertEqual(collector.pollRetries, 3)
        XCTAssertEqual(collector.retriesAllowed, 3)
        XCTAssertEqual(collector.pollInterval, 2000)
    }

    // MARK: - eventType

    func testEventType() {
        let collector = PollingCollector(with: [:])
        XCTAssertEqual(collector.eventType(), Constants.pollingEventType)
    }

    // MARK: - close

    func testCloseResetsValue() {
        let collector = PollingCollector(with: [:])
        collector.value = "someValue"
        collector.close()
        XCTAssertEqual(collector.value, "")
    }

    // MARK: - payload

    func testPayloadReturnsValueWhenSet() {
        let collector = PollingCollector(with: [:])
        collector.value = "approved"
        XCTAssertEqual(collector.payload(), "approved")
    }

    func testPayloadReturnsNilWhenValueIsEmpty() {
        let collector = PollingCollector(with: [:])
        XCTAssertNil(collector.payload())
    }

    // MARK: - Simple polling mode: timedOut (retriesAllowed == 1)

    func testSimplePollTimedOut() async {
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "1",
            "pollChallengeStatus": false
        ]
        let collector = PollingCollector(with: json)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() {
            statuses.append(status)
        }

        // First status is .continuing (emitted before sleeping), second is .timedOut.
        XCTAssertEqual(statuses.count, 2)
        if case .continue(let attempt, let total) = statuses[0] {
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(total, 1)
        } else {
            XCTFail("Expected .continuing as first status, got \(statuses[0])")
        }
        if case .timedOut = statuses[1] {
            XCTAssertEqual(collector.value, Constants.pollingValueTimedOut)
        } else {
            XCTFail("Expected .timedOut as second status, got \(statuses[1])")
        }
    }

    // MARK: - Simple polling mode: continue (retriesAllowed > 1)

    func testSimplePollEmitsCompleteWithContinueStatus() async {
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "5",
            "pollChallengeStatus": false
        ]
        let collector = PollingCollector(with: json)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() {
            statuses.append(status)
        }

        // First status is .continuing (emitted before sleeping), second is .complete.
        XCTAssertEqual(statuses.count, 2)
        if case .continue(let attempt, let total) = statuses[0] {
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(total, 5)
        } else {
            XCTFail("Expected .continuing as first status, got \(statuses[0])")
        }
        if case .complete(let status) = statuses[1] {
            XCTAssertEqual(status, Constants.pollingValueContinue)
            XCTAssertEqual(collector.value, Constants.pollingValueContinue)
        } else {
            XCTFail("Expected .complete(status: \"continue\") as second status, got \(statuses[1])")
        }
    }

    func testSimplePollDecrementsRetriesAllowed() async {
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "3",
            "pollChallengeStatus": false
        ]
        let collector = PollingCollector(with: json)
        XCTAssertEqual(collector.retriesAllowed, 3)

        for await _ in collector.poll() {}

        XCTAssertEqual(collector.retriesAllowed, 2)
    }

    // MARK: - Simple polling mode: invalid interval

    func testSimplePollZeroIntervalEmitsError() async {
        let json: [String: Any] = [
            "pollInterval": "0",
            "pollChallengeStatus": false
        ]
        let collector = PollingCollector(with: json)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() {
            statuses.append(status)
        }

        XCTAssertEqual(statuses.count, 1)
        if case .error = statuses[0] {
            XCTAssertEqual(collector.value, Constants.pollingValueError)
        } else {
            XCTFail("Expected .error for zero interval, got \(statuses[0])")
        }
    }

    // MARK: - Challenge mode: missing configuration

    func testChallengePollWithNilContinueNodeEmitsError() async {
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "3",
            "pollChallengeStatus": true,
            "challenge": "abc123"
        ]
        let collector = PollingCollector(with: json)
        // continueNode and davinci are intentionally not set

        var statuses: [PollingStatus] = []
        for await status in collector.poll() {
            statuses.append(status)
        }

        XCTAssertEqual(statuses.count, 1)
        if case .error = statuses[0] {
            XCTAssertEqual(collector.value, Constants.pollingValueError)
        } else {
            XCTFail("Expected .error due to missing configuration, got \(statuses[0])")
        }
    }

    func testChallengePollWithEmptyChallengeUsesSimpleMode() async {
        // pollChallengeStatus = true but challenge is empty → falls back to simple mode
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "5",
            "pollChallengeStatus": true,
            "challenge": ""
        ]
        let collector = PollingCollector(with: json)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() {
            statuses.append(status)
        }

        // Simple mode: .continuing emitted first, then .complete.
        XCTAssertEqual(statuses.count, 2)
        if case .continue = statuses[0] { } else {
            XCTFail("Expected .continuing as first status, got \(statuses[0])")
        }
        if case .complete(let status) = statuses[1] {
            XCTAssertEqual(status, Constants.pollingValueContinue)
        } else {
            XCTFail("Expected simple mode .complete as second status, got \(statuses[1])")
        }
    }

    // MARK: - Challenge mode: single-cycle polling with network

    /// Strong reference kept here so the `weak var continueNode` on `PollingCollector`
    /// isn't deallocated before `poll()` executes.
    private var challengeNode: ContinueNode?

    /// Builds a challenge-mode collector wired to a mock HTTP client.
    private func makeChallengeCollector(retries: Int = 3) -> PollingCollector {
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": String(retries),
            "pollChallengeStatus": true,
            "challenge": "test-challenge"
        ]
        let collector = PollingCollector(with: json)
        let input: [String: Any] = [
            "id": "test-connector-id",
            "_links": ["self": ["href": "http://localhost/davinci/connections/ABC/capabilities/customForm"]],
            "interactionId": "test-interaction-id"
        ]
        let flowCtx = FlowContext(flowContext: SharedContext())
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = MockURLProtocol.makeClient()
        }
        let node = MockContinueNodeForChallenge(
            context: flowCtx, workflow: workflow, input: input, actions: [])
        // Note: davinci is intentionally NOT set here — pollForChallengeStatus now derives the
        // HTTP client from continueNode.workflow directly, so DaVinciAware injection is not needed.
        challengeNode = node  // retain strongly so the weak continueNode stays valid during poll()
        collector.continueNode = node
        return collector
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
        challengeNode = nil
    }

    func testChallengePollEmitsContinuingThenCompletesWhenChallengeComplete() async {
        let body = #"{"isChallengeComplete":true,"status":"approved"}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                             httpVersion: nil, headerFields: nil)!, body)
        }
        let collector = makeChallengeCollector()

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        XCTAssertEqual(statuses.count, 2)
        if case .continue(let attempt, let total) = statuses[0] {
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(total, 3)
        } else { XCTFail("Expected .continuing, got \(statuses[0])") }
        if case .complete(let status) = statuses[1] {
            XCTAssertEqual(status, "approved")
            XCTAssertEqual(collector.value, "approved")
        } else { XCTFail("Expected .complete(\"approved\"), got \(statuses[1])") }
    }

    func testChallengePollLoopsInternallyUntilChallengeComplete() async {
        // Challenge not complete on first two calls, complete on the third.
        // The collector must poll the status endpoint in a loop — no DaVinci re-submit between cycles.
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            let body = callCount >= 3
                ? #"{"isChallengeComplete":true,"status":"approved"}"#.data(using: .utf8)!
                : #"{"isChallengeComplete":false}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, body)
        }
        let collector = makeChallengeCollector(retries: 5)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        // Three .continuing updates then .complete — all inside one poll() invocation.
        XCTAssertEqual(statuses.count, 4)
        for (i, status) in statuses.dropLast().enumerated() {
            if case .continue(let attempt, let total) = status {
                XCTAssertEqual(attempt, i + 1)
                XCTAssertEqual(total, 5)
            } else { XCTFail("Expected .continuing at index \(i), got \(status)") }
        }
        if case .complete(let s) = statuses.last! {
            XCTAssertEqual(s, "approved")
            XCTAssertEqual(collector.value, "approved")
        } else { XCTFail("Expected .complete(\"approved\") as last status, got \(statuses.last!)") }
    }

    func testChallengePollContinuesOnTransientNon200() async {
        // First call returns 503 (transient), second returns challenge complete.
        // The collector must treat non-400 non-200 as transient and keep polling.
        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 503,
                                        httpVersion: nil, headerFields: nil)!, Data())
            }
            let body = #"{"isChallengeComplete":true,"status":"approved"}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, body)
        }
        let collector = makeChallengeCollector(retries: 3)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        // .continuing(1,3), .continuing(2,3), .complete("approved") — 503 was absorbed.
        XCTAssertEqual(statuses.count, 3)
        if case .complete(let s) = statuses.last! {
            XCTAssertEqual(s, "approved")
        } else { XCTFail("Expected .complete after transient 503, got \(statuses.last!)") }
    }

    func testChallengePollEmitsContinuingThenTimedOutOnLastRetry() async {
        let body = #"{"isChallengeComplete":false}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                             httpVersion: nil, headerFields: nil)!, body)
        }
        let collector = makeChallengeCollector(retries: 1)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        XCTAssertEqual(statuses.count, 2)
        if case .continue(let attempt, let total) = statuses[0] {
            XCTAssertEqual(attempt, 1)
            XCTAssertEqual(total, 1)
        } else { XCTFail("Expected .continuing, got \(statuses[0])") }
        if case .timedOut = statuses[1] {
            XCTAssertEqual(collector.value, Constants.pollingValueTimedOut)
        } else { XCTFail("Expected .timedOut, got \(statuses[1])") }
    }

    func testChallengePollEmitsExpiredOnHTTP400() async {
        // HTTP 400 specifically signals challenge expiry and must terminate polling.
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 400,
                             httpVersion: nil, headerFields: nil)!, Data())
        }
        let collector = makeChallengeCollector()

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        XCTAssertEqual(statuses.count, 2)
        if case .continue = statuses[0] { } else {
            XCTFail("Expected .continuing, got \(statuses[0])")
        }
        if case .expired = statuses[1] {
            XCTAssertEqual(collector.value, Constants.pollingValueExpired)
        } else { XCTFail("Expected .expired on HTTP 400, got \(statuses[1])") }
    }

    func testChallengePollEmitsErrorOnInvalidJSONResponse() async {
        // Server returns 200 but the body is not valid JSON → must emit .error(.invalidResponse).
        let body = "not-json".data(using: .utf8)!
        MockURLProtocol.requestHandler = { _ in
            (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                             httpVersion: nil, headerFields: nil)!, body)
        }
        let collector = makeChallengeCollector(retries: 1)

        var statuses: [PollingStatus] = []
        for await status in collector.poll() { statuses.append(status) }

        XCTAssertEqual(statuses.count, 2)
        if case .continue = statuses[0] { } else {
            XCTFail("Expected .continuing, got \(statuses[0])")
        }
        if case .error(let err) = statuses[1] {
            XCTAssertEqual(collector.value, Constants.pollingValueError)
            XCTAssertTrue(err is PollingError)
        } else { XCTFail("Expected .error(.invalidResponse), got \(statuses[1])") }
    }

    func testChallengeWithSpecialCharactersIsURLEncoded() async {
        // Challenge containing URL-unsafe characters (/, ?, #, %) must be percent-encoded.
        let json: [String: Any] = [
            "pollInterval": "1",
            "pollRetries": "1",
            "pollChallengeStatus": true,
            "challenge": "abc/123?foo#bar%25"
        ]
        let collector = PollingCollector(with: json)
        let input: [String: Any] = [
            "id": "connector-id",
            "_links": ["self": ["href": "http://localhost/davinci/connections/ABC/capabilities/customForm"]],
            "interactionId": "interaction-id"
        ]
        let flowCtx = FlowContext(flowContext: SharedContext())
        let workflow = Workflow.createWorkflow { config in
            config.httpClient = MockURLProtocol.makeClient()
        }
        let node = MockContinueNodeForChallenge(
            context: flowCtx, workflow: workflow, input: input, actions: [])
        challengeNode = node
        collector.continueNode = node

        var capturedURL: String?
        let body = #"{"isChallengeComplete":true,"status":"approved"}"#.data(using: .utf8)!
        MockURLProtocol.requestHandler = { request in
            capturedURL = request.url?.absoluteString
            return (HTTPURLResponse(url: URL(string: "http://localhost")!, statusCode: 200,
                                    httpVersion: nil, headerFields: nil)!, body)
        }

        for await _ in collector.poll() {}

        // Verify the challenge was percent-encoded in the request URL.
        XCTAssertNotNil(capturedURL)
        XCTAssertTrue(capturedURL!.contains("abc%2F123%3Ffoo%23bar%2525"), "Expected URL-encoded challenge in: \(capturedURL!)")
    }
}

// MARK: - Mock helpers

private class MockContinueNodeForChallenge: ContinueNode, @unchecked Sendable {
    override func asRequest() -> Request {
        return URLSessionHttpRequest()
    }
}
