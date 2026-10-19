//
//  DaVinciPARE2ETest.swift
//  DavinciTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingLogger

/// Real-server E2E coverage for the OIDC `par` flag on the DaVinci path.
///
/// Two scenarios — driven against the same PingOne tenant that backs
/// `DaVinciIntegrationTests`:
/// - `par = false` — classic flow: GET `/authorize` carries all auth params in the URL
///   (including `response_mode=pi.flow`, `acr_values`, `code_challenge`, `state`, etc.).
/// - `par = true`  — RFC 9126 flow: POST `/par` with the same params as form fields,
///   then GET `/authorize?response_mode=pi.flow&request_uri=...&client_id=...` and
///   nothing else from the pushed set.
///
/// A `RecordingHttpClient` is wired onto `DaVinciConfig.httpClient` so the
/// `OidcModule.initialize` hook (`Davinci/Davinci/module/Oidc.swift:33`) propagates
/// it into the OIDC sub-config. Assertions are made against the captured wire history.
final class DaVinciPARE2ETest: DaVinciBaseTests, @unchecked Sendable {

    private var username: String!
    private var password: String!

    override func setUp() async throws {
        self.configFileName = "DaVinci-e2e-config"
        try await super.setUp()
        username = self.config.username
        password = self.config.password
    }

    // MARK: - par = false

    func testDaVinciLoginWithoutPAR() async throws {
        let recorder = RequestRecorder()
        let daVinci = makeDaVinci(recorder: recorder, par: false)
        await daVinci.daVinciUser()?.logout()

        try await driveLogin(daVinci: daVinci)

        // No /par request when the flag is off.
        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertTrue(parCalls.isEmpty, "Expected zero PAR calls when par=false; got \(parCalls.count)")

        // /authorize should carry the full param set inline (including pi.flow + acr).
        guard let authorize = recorder.history.first(where: { $0.url?.path.contains("/authorize") ?? false }) else {
            XCTFail("Expected an /authorize request in recorded history")
            return
        }
        XCTAssertEqual(authorize.method, "GET")
        let names = Set(authorize.queryItems().map { $0.name })
        for required in [
            "client_id", "response_type", "scope", "redirect_uri",
            "code_challenge", "code_challenge_method", "state",
            "response_mode", "acr_values"
        ] {
            XCTAssertTrue(names.contains(required), "Expected /authorize query to include \(required); got \(names)")
        }
        XCTAssertFalse(names.contains("request_uri"), "Did not expect request_uri in classic flow")
    }

    // MARK: - par = true

    func testDaVinciLoginWithPAR() async throws {
        let recorder = RequestRecorder()
        let daVinci = makeDaVinci(recorder: recorder, par: true)
        await daVinci.daVinciUser()?.logout()

        try await driveLogin(daVinci: daVinci)

        // Exactly one /par POST with the expected form fields.
        let parCalls = recorder.all(matchingPathSuffix: "/par")
        XCTAssertEqual(parCalls.count, 1, "Expected exactly one /par request; got \(parCalls.count)")
        let parRequest = parCalls[0]
        XCTAssertEqual(parRequest.method, "POST")
        let parFields = parRequest.formFields()
        for field in [
            "client_id", "response_type", "scope", "redirect_uri",
            "code_challenge", "code_challenge_method", "state",
            "response_mode", "acr_values"
        ] {
            XCTAssertNotNil(parFields[field], "PAR body missing form field \(field); got \(parFields.keys)")
        }
        XCTAssertEqual(parFields["client_id"], self.config.clientId)
        XCTAssertEqual(parFields["response_type"], "code")
        XCTAssertEqual(parFields["response_mode"], "pi.flow")

        // /authorize should carry only client_id + request_uri + response_mode.
        guard let authorize = recorder.history.first(where: { $0.url?.path.contains("/authorize") ?? false }) else {
            XCTFail("Expected an /authorize request in recorded history")
            return
        }
        XCTAssertEqual(authorize.method, "GET")
        let authNames = Set(authorize.queryItems().map { $0.name })
        // DaVinci keeps response_mode on /authorize even with PAR (see manual logs);
        // everything else from the PAR-pushed set must be absent.
        XCTAssertTrue(authNames.contains("client_id"), "Expected client_id in /authorize query; got \(authNames)")
        XCTAssertTrue(authNames.contains("request_uri"), "Expected request_uri in /authorize query; got \(authNames)")
        XCTAssertTrue(authNames.contains("response_mode"), "Expected response_mode in /authorize query when PAR is used; got \(authNames)")
        for forbidden in ["scope", "redirect_uri", "code_challenge", "code_challenge_method", "state", "acr_values"] {
            XCTAssertFalse(
                authNames.contains(forbidden),
                "Did not expect \(forbidden) on /authorize when PAR is used; got \(authNames)"
            )
        }

        let authorizeRequestUri = authorize.queryItems().first { $0.name == "request_uri" }?.value
        XCTAssertNotNil(authorizeRequestUri)
        XCTAssertFalse(authorizeRequestUri?.isEmpty ?? true, "request_uri should not be empty")
    }

    // MARK: - Helpers

    private func makeDaVinci(recorder: RequestRecorder, par: Bool) -> DaVinci {
        let clientId = self.config.clientId
        let scopes = self.config.scopes
        let redirectUri = self.config.redirectUri
        let acrValues = self.config.acrValues
        let discoveryEndpoint = self.config.discoveryEndpoint

        return DaVinci.createDaVinci { config in
            config.logger = LogManager.standard
            config.httpClient = RecordingHttpClient(recorder: recorder)
            config.module(PingDavinci.OidcModule.config) { oidcValue in
                oidcValue.clientId = clientId
                oidcValue.scopes = Set(scopes)
                oidcValue.redirectUri = redirectUri
                oidcValue.acrValues = acrValues
                oidcValue.discoveryEndpoint = discoveryEndpoint
                oidcValue.par = par
            }
        }
    }

    /// Drives the standard E2E DaVinci login flow used by `DaVinciIntegrationTests`:
    /// `E2E Login Form` -> `Successful login` -> `SuccessNode` and asserts a token.
    private func driveLogin(daVinci: DaVinci) async throws {
        var node = await daVinci.start()
        guard var continueNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode for the login form, got \(type(of: node))")
            return
        }
        XCTAssertEqual("E2E Login Form", continueNode.name)

        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"

        node = await continueNode.next()
        guard let next = node as? ContinueNode else {
            XCTFail("Expected ContinueNode for 'Successful login', got \(type(of: node))")
            return
        }
        continueNode = next
        XCTAssertEqual("Successful login", continueNode.name)

        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        node = await continueNode.next()
        guard let success = node as? SuccessNode else {
            XCTFail("Expected SuccessNode, got \(type(of: node))")
            return
        }

        guard case let .success(token) = await success.user?.token() else {
            XCTFail("Expected token retrieval to succeed")
            return
        }
        XCTAssertFalse(token.accessToken.isEmpty)
    }
}
