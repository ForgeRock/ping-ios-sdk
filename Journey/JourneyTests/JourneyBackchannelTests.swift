//
//  JourneyBackchannelTests.swift
//  JourneyTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import PingJourneyPlugin
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingNetwork

final class JourneyBackchannelTests: XCTestCase, @unchecked Sendable {

    override func setUp() {
        super.setUp()
        MockURLProtocol.startInterceptingRequests()
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.stopInterceptingRequests()
    }

    // MARK: - Helpers

    /// Matches `JourneyTests`/`JourneyContinueNodeTests`' `Config.json` values (`serverUrl` includes the
    /// `/am` deployment path segment; `realm` is `alpha`, no leading slash).
    private let serverUrl = "https://openam-sdks.forgeblocks.com/am"
    private let configRealm = "alpha"

    /// The authenticate endpoint path built by `Request.populateRequest` from `JourneyConfig.serverUrl` +
    /// `JourneyConfig.realm`: `{serverUrl}/json/realms/{realm}/authenticate`.
    private var authenticatePath: String { "/am/json/realms/\(configRealm)/authenticate" }

    /// Builds a `Journey` configured with a `JourneyConfig` whose `httpClient` is wired to
    /// `MockURLProtocol` (mirrors `OidcDeviceApprovalTests.makeJourney()`).
    private func makeJourney() -> Journey {
        Journey.createJourney { journeyConfig in
            journeyConfig.serverUrl = self.serverUrl
            journeyConfig.realm = self.configRealm
            journeyConfig.cookie = "iPlanetDirectoryPro"
            journeyConfig.httpClient = MockURLProtocol.makeClient()
        }
    }

    /// Builds a gateway `redirectUri`, mirroring AM's `/authenticate/backchannel/initialize` response shape:
    /// `.../UI/Login?realm=%2F<realm>&authIndexType=<type>&authIndexValue=<value>`.
    /// The `realm` query parameter is deliberately different from `JourneyConfig.realm` ("alpha") to prove
    /// the SDK never honours the URI's realm.
    private func backchannelRedirectUri(
        realm: String = "%2Fbravo",
        authIndexType: String? = JourneyConstants.transaction,
        authIndexValue: String? = UUID().uuidString
    ) -> URL {
        var query = "realm=\(realm)"
        if let authIndexType {
            query += "&authIndexType=\(authIndexType)"
        }
        if let authIndexValue {
            query += "&authIndexValue=\(authIndexValue)"
        }
        return URL(string: "https://openam-sdks.forgeblocks.com/am/UI/Login?\(query)")!
    }

    private func jsonResponse(statusCode: Int, url: URL, body: [String: Any]) throws -> (HTTPURLResponse, Data) {
        let data = try JSONSerialization.data(withJSONObject: body)
        return (HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: MockResponse.headers)!, data)
    }

    // MARK: - Task 3.1 — Cases 1-5

    func testHappyPath_continueNode() async throws {
        let journey = makeJourney()
        let transactionId = UUID().uuidString
        let uri = backchannelRedirectUri(authIndexValue: transactionId)

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 200, url: request.url!, body: [
                "authId": "test-auth-id",
                "callbacks": []
            ])
        }

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is JourneyContinueNode, "Expected JourneyContinueNode but got \(type(of: node))")

        guard let authenticateRequest = MockURLProtocol.requestHistory.first(where: { $0.url?.path == authenticatePath }) else {
            XCTFail("Expected an authenticate request to have been captured")
            return
        }

        let queryItems = URLComponents(url: authenticateRequest.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(queryItems.first(where: { $0.name == JourneyConstants.authIndexType })?.value, JourneyConstants.transaction)
        XCTAssertEqual(queryItems.first(where: { $0.name == JourneyConstants.authIndexValue })?.value, transactionId)
        XCTAssertEqual(authenticateRequest.url?.path, authenticatePath, "Should use JourneyConfig.realm, not the URI's realm")
    }

    func testHappyPath_successNode() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 200, url: request.url!, body: [
                "tokenId": "test-token-id",
                "successUrl": "/am/console"
            ])
        }

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode but got \(type(of: node))")
    }

    func testInvalidUri_missingAuthIndexType() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: nil, authIndexValue: UUID().uuidString)

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_missingAuthIndexValue() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: JourneyConstants.transaction, authIndexValue: nil)

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_emptyAuthIndexType() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: "", authIndexValue: UUID().uuidString)

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_emptyAuthIndexValue() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: JourneyConstants.transaction, authIndexValue: "")

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_whitespaceOnlyAuthIndexType() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: "%20", authIndexValue: UUID().uuidString)

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_whitespaceOnlyAuthIndexValue() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri(authIndexType: JourneyConstants.transaction, authIndexValue: "%20")

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_noQueryItems() async throws {
        let journey = makeJourney()
        let uri = URL(string: "https://openam-sdks.forgeblocks.com/am/UI/Login")!

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testInvalidUri_hostMismatch() async throws {
        let journey = makeJourney()
        let uri = URL(string: "https://attacker.example.com/am/UI/Login?authIndexType=\(JourneyConstants.transaction)&authIndexValue=\(UUID().uuidString)")!

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is FailureNode, "Expected FailureNode but got \(type(of: node))")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testHostMatchIsCaseInsensitive() async throws {
        let journey = makeJourney()
        // Same host as JourneyConfig.serverUrl but upper-cased — hostnames are case-insensitive.
        let uri = URL(string: "https://OPENAM-SDKS.FORGEBLOCKS.COM/am/UI/Login?authIndexType=\(JourneyConstants.transaction)&authIndexValue=\(UUID().uuidString)")!

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 200, url: request.url!, body: [
                "authId": "test-auth-id",
                "callbacks": []
            ])
        }

        let node = await journey.start(backchannelUri: uri)

        XCTAssertTrue(node is JourneyContinueNode, "Expected JourneyContinueNode but got \(type(of: node))")
        XCTAssertFalse(MockURLProtocol.requestHistory.isEmpty, "An authenticate request should have been made")
    }

    // MARK: - Task 3.2 — Cases 6-9

    func testJourneyConfigAbsent() async throws {
        let journey = Workflow(config: WorkflowConfig())
        let uri = backchannelRedirectUri()

        let node = await journey.start(backchannelUri: uri)

        guard let failureNode = node as? FailureNode else {
            XCTFail("Expected FailureNode but got \(type(of: node))")
            return
        }

        guard let apiError = failureNode.cause as? ApiError,
              case .error(let status, _, let message) = apiError else {
            XCTFail("Expected ApiError cause but got \(failureNode.cause)")
            return
        }

        XCTAssertEqual(status, 400)
        XCTAssertEqual(message, "JourneyConfig missing")
        XCTAssertTrue(MockURLProtocol.requestHistory.isEmpty, "No network request should have been made")
    }

    func testNoSessionFlagIsSentOnTheAuthenticateRequest() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 200, url: request.url!, body: [
                "authId": "test-auth-id",
                "callbacks": []
            ])
        }

        _ = await journey.start(backchannelUri: uri) { options in
            options.noSession = true
        }

        guard let authenticateRequest = MockURLProtocol.requestHistory.first(where: { $0.url?.path == authenticatePath }) else {
            XCTFail("Expected an authenticate request to have been captured")
            return
        }

        XCTAssertTrue(authenticateRequest.url?.absoluteString.contains("noSession=true") ?? false)
    }

    func testForceAuthFlagIsSentOnTheAuthenticateRequest() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 200, url: request.url!, body: [
                "authId": "test-auth-id",
                "callbacks": []
            ])
        }

        _ = await journey.start(backchannelUri: uri) { options in
            options.forceAuth = true
        }

        guard let authenticateRequest = MockURLProtocol.requestHistory.first(where: { $0.url?.path == authenticatePath }) else {
            XCTFail("Expected an authenticate request to have been captured")
            return
        }

        XCTAssertTrue(authenticateRequest.url?.absoluteString.contains("ForceAuth=true") ?? false)
    }

    func testAM4xxReturnsErrorNodeWithAMMessage() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()
        let expectedMessage = "Transaction expired"

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 400, url: request.url!, body: [
                "code": 400,
                "reason": "Bad Request",
                "message": expectedMessage
            ])
        }

        let node = await journey.start(backchannelUri: uri)

        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode but got \(type(of: node))")
            return
        }

        XCTAssertEqual(errorNode.message, expectedMessage)
    }

    func testAM5xxWithParseableBodyReturnsErrorNodeWithAMMessage() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()
        let expectedMessage = "Unable to approve transaction"

        MockURLProtocol.requestHandler = { request in
            try self.jsonResponse(statusCode: 500, url: request.url!, body: [
                "code": 500,
                "reason": "Internal Server Error",
                "message": expectedMessage
            ])
        }

        let node = await journey.start(backchannelUri: uri)

        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode but got \(type(of: node))")
            return
        }

        XCTAssertEqual(errorNode.message, expectedMessage)
        XCTAssertEqual(errorNode.status, 500)
    }

    func testAM5xxWithUnparseableBodyReturnsFailureNode() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()

        MockURLProtocol.requestHandler = { request in
            let data = Data("Internal Server Error".utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, data)
        }

        let node = await journey.start(backchannelUri: uri)

        guard let failureNode = node as? FailureNode else {
            XCTFail("Expected FailureNode but got \(type(of: node))")
            return
        }

        guard let apiError = failureNode.cause as? ApiError,
              case .error(let status, _, _) = apiError else {
            XCTFail("Expected ApiError cause but got \(failureNode.cause)")
            return
        }

        XCTAssertEqual(status, 500)
    }

    func testAM5xxWithNonObjectJsonBodyReturnsErrorNodeWithEmptyMessage() async throws {
        let journey = makeJourney()
        let uri = backchannelRedirectUri()

        MockURLProtocol.requestHandler = { request in
            let data = try JSONSerialization.data(withJSONObject: [])
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: MockResponse.headers)!, data)
        }

        let node = await journey.start(backchannelUri: uri)

        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode but got \(type(of: node))")
            return
        }

        XCTAssertEqual(errorNode.message, "")
    }
}
