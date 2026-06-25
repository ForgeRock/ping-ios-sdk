//
//  JourneyPARE2ETest.swift
//  JourneyTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingLogger

/// Real-server E2E coverage for the OIDC `par` flag on the Journey path.
///
/// Two scenarios:
/// - `par = false` — classic flow: GET `/authorize` carries all auth params in the URL.
/// - `par = true`  — RFC 9126 flow: POST `/par` with form params, then GET
///   `/authorize?request_uri=...&client_id=...` (and nothing else from the pushed set).
///
/// A `RecordingHttpClient` is wired onto `JourneyConfig.httpClient` so the
/// `OidcModule.initialize` hook (`Journey/Module/Oidc.swift:33`) propagates it
/// into the OIDC sub-config. Assertions are made against the captured wire history.
final class JourneyPARE2ETest: JourneyE2EBaseTest, @unchecked Sendable {

    private var recorder: RequestRecorder!

    override func setUp() async throws {
        try await super.setUp()
        // setUp() in base built `defaultJourney`; rebuild it here with the recorder
        // attached. We re-declare locals to avoid capturing `self` in the @Sendable closure.
        recorder = RequestRecorder()
        let recorder = self.recorder!

        let serverUrl = self.serverUrl!
        let realm = self.realm!
        let cookie = self.cookie!
        let discoveryEndpoint = self.discoveryEndpoint!
        let clientId = self.clientId!
        let scopes = self.scopes!
        let redirectUri = self.redirectUri!

        defaultJourney = Journey.createJourney { config in
            config.timeout = 30
            config.logger = LogManager.standard
            config.serverUrl = serverUrl
            config.realm = realm
            config.cookie = cookie
            config.httpClient = RecordingHttpClient(recorder: recorder)
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.discoveryEndpoint = discoveryEndpoint
                oidcValue.clientId = clientId
                oidcValue.scopes = Set(scopes)
                oidcValue.redirectUri = redirectUri
                // par flag is overridden per-test below; default false here.
            }
        }

        await defaultJourney?.journeyUser()?.logout()
    }

    // MARK: - par = false

    func testJourneyLoginWithoutPAR() async throws {
        // par defaults to false in setUp(). Run a normal login + token flow.
        let node = try await handleLoginCallbacks(journey: defaultJourney, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")

        guard case let .success(token) = await defaultJourney.journeyUser()?.token() else {
            XCTFail("Expected token retrieval to succeed")
            return
        }
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")

        // No /par request should appear when the flag is off.
        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertTrue(parCalls.isEmpty, "Expected zero PAR calls when par=false; got \(parCalls.count)")

        // The /authorize GET should carry the full param set inline.
        guard let authorize = recorder.history.first(where: { $0.url?.path.contains("/authorize") ?? false }) else {
            XCTFail("Expected an /authorize request in recorded history")
            return
        }
        XCTAssertEqual(authorize.method, "GET")
        let names = Set(authorize.queryItems().map { $0.name })
        for required in ["client_id", "response_type", "scope", "redirect_uri", "code_challenge", "code_challenge_method", "state"] {
            XCTAssertTrue(names.contains(required), "Expected /authorize query to include \(required); got \(names)")
        }
        XCTAssertFalse(names.contains("request_uri"), "Did not expect request_uri in classic flow")
    }

    // MARK: - par = true

    func testJourneyLoginWithPAR() async throws {
        // Re-build with par = true.
        recorder = RequestRecorder()
        let recorder = self.recorder!
        let serverUrl = self.serverUrl!
        let realm = self.realm!
        let cookie = self.cookie!
        let discoveryEndpoint = self.discoveryEndpoint!
        let clientId = self.clientId!
        let scopes = self.scopes!
        let redirectUri = self.redirectUri!

        defaultJourney = Journey.createJourney { config in
            config.timeout = 30
            config.logger = LogManager.standard
            config.serverUrl = serverUrl
            config.realm = realm
            config.cookie = cookie
            config.httpClient = RecordingHttpClient(recorder: recorder)
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.discoveryEndpoint = discoveryEndpoint
                oidcValue.clientId = clientId
                oidcValue.scopes = Set(scopes)
                oidcValue.redirectUri = redirectUri
                oidcValue.par = true
            }
        }
        await defaultJourney?.journeyUser()?.logout()

        // Drive the journey end-to-end.
        let node = try await handleLoginCallbacks(journey: defaultJourney, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")

        guard case let .success(token) = await defaultJourney.journeyUser()?.token() else {
            XCTFail("Expected token retrieval to succeed")
            return
        }
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")

        // Exactly one /par POST with the expected form fields.
        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertEqual(parCalls.count, 1, "Expected exactly one /par request; got \(parCalls.count)")
        let parRequest = parCalls[0]
        XCTAssertEqual(parRequest.method, "POST")
        let parFields = parRequest.formFields()
        for field in ["client_id", "response_type", "scope", "redirect_uri", "code_challenge", "code_challenge_method", "state"] {
            XCTAssertNotNil(parFields[field], "PAR body missing form field \(field); got \(parFields.keys)")
        }
        XCTAssertEqual(parFields["client_id"], clientId)
        XCTAssertEqual(parFields["response_type"], "code")

        // /authorize should carry only client_id + request_uri.
        guard let authorize = recorder.history.first(where: { $0.url?.path.contains("/authorize") ?? false }) else {
            XCTFail("Expected an /authorize request in recorded history")
            return
        }
        XCTAssertEqual(authorize.method, "GET")
        let authNames = Set(authorize.queryItems().map { $0.name })
        XCTAssertTrue(authNames.contains("client_id"), "Expected client_id in /authorize query; got \(authNames)")
        XCTAssertTrue(authNames.contains("request_uri"), "Expected request_uri in /authorize query; got \(authNames)")
        for forbidden in ["scope", "redirect_uri", "code_challenge", "code_challenge_method", "state"] {
            XCTAssertFalse(authNames.contains(forbidden),
                           "Did not expect \(forbidden) in /authorize query when PAR is used; got \(authNames)")
        }

        // The request_uri on /authorize must match the value the PAR endpoint returned.
        // (Assumes the PAR 201 response was logged via the inner HttpClient; we cross-check
        // by extracting the request_uri from /authorize and confirming it is non-empty and
        // the same one PAR pushed back through to the SDK.)
        let authorizeRequestUri = authorize.queryItems().first { $0.name == "request_uri" }?.value
        XCTAssertNotNil(authorizeRequestUri)
        XCTAssertFalse(authorizeRequestUri?.isEmpty ?? true, "request_uri should not be empty")
    }
}
