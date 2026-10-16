// 
//  OidcWebClientTests.swift
//  Oidc
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
import PingBrowser
import PingLogger
import PingNetwork
import PingOrchestrate

class OidcWebClientTests: XCTestCase {
    var oidcWebClient: OidcWebClient?
    
    override func setUp() {
        super.setUp()
        
        self.oidcWebClient = OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "TestClientId"
                oidcValue.scopes = Set("openid profile email".split(separator: " ").map { String($0) })
                oidcValue.redirectUri = "https://example.com/callback"
                oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
            }
        }
    }

    override func tearDown() async throws {
        await MainActor.run { BrowserLauncher.currentBrowser = BrowserLauncher() }
        try await super.tearDown()
    }

    func testOidcWeb() throws {
        guard let oidcWeb = self.oidcWebClient else {
            XCTFail("Failed to create Journey instance")
            return
        }
        
        XCTAssertEqual(oidcWeb.config.modules.count, 2)
        XCTAssertEqual(oidcWeb.signOffHandlers.count, 1)
        XCTAssertEqual(oidcWeb.successHandlers.count, 1)
    }
    
    func testOidcWebConfig() throws {
        guard let oidcWeb = self.oidcWebClient else {
            XCTFail("Failed to create Journey instance")
            return
        }

        let oidcWebConfig = oidcWeb.config as? OidcWebClientConfig
        XCTAssertNotNil(oidcWebConfig)
        XCTAssertEqual(oidcWebConfig?.browserMode, .login)
        XCTAssertEqual(oidcWebConfig?.browserType, .authSession)
    }

    // MARK: - authorizeResult(from:)

    func testAuthorizeResultPreservesAuthorizeErrorWrappingExternalUserAgentCancelled() {
        let failureNode = FailureNode(cause: OidcError.authorizeError(cause: BrowserError.externalUserAgentCancelled, message: "Browser authorization failed"))

        let result = OidcWebClient.authorizeResult(from: failureNode)

        switch result {
        case .failure(let error):
            guard case .authorizeError(let cause, _) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            guard case .some(BrowserError.externalUserAgentCancelled) = cause as? BrowserError else {
                XCTFail("Expected cause to be BrowserError.externalUserAgentCancelled, got \(String(describing: cause))")
                return
            }
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }

    func testAuthorizeResultPreservesAuthorizeErrorWrappingHttpsCallbackUnsupportedOS() {
        let failureNode = FailureNode(cause: OidcError.authorizeError(cause: BrowserError.httpsCallbackUnsupportedOS, message: "Browser authorization failed"))

        let result = OidcWebClient.authorizeResult(from: failureNode)

        switch result {
        case .failure(let error):
            guard case .authorizeError(let cause, _) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            guard case .some(BrowserError.httpsCallbackUnsupportedOS) = cause as? BrowserError else {
                XCTFail("Expected cause to be BrowserError.httpsCallbackUnsupportedOS, got \(String(describing: cause))")
                return
            }
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }

    func testAuthorizeResultPreservesAuthorizeErrorWrappingInvalidHTTPSRedirectConfiguration() {
        let failureNode = FailureNode(cause: OidcError.authorizeError(cause: BrowserError.invalidHTTPSRedirectConfiguration, message: "Browser authorization failed"))

        let result = OidcWebClient.authorizeResult(from: failureNode)

        switch result {
        case .failure(let error):
            guard case .authorizeError(let cause, _) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            guard case .some(BrowserError.invalidHTTPSRedirectConfiguration) = cause as? BrowserError else {
                XCTFail("Expected cause to be BrowserError.invalidHTTPSRedirectConfiguration, got \(String(describing: cause))")
                return
            }
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }

    func testAuthorizeResultWrapsNonOidcErrorInUnknownWithoutDiscardingCause() {
        struct TestError: Error, Equatable {
            let identifier: String
        }
        let originalCause = TestError(identifier: "some-non-oidc-error")
        let failureNode = FailureNode(cause: originalCause)

        let result = OidcWebClient.authorizeResult(from: failureNode)

        switch result {
        case .failure(let error):
            guard case .unknown(let cause, _) = error else {
                XCTFail("Expected .unknown, got \(error)")
                return
            }
            guard let typedCause = cause as? TestError else {
                XCTFail("Expected cause to be the original TestError instance, got \(String(describing: cause))")
                return
            }
            XCTAssertEqual(typedCause, originalCause)
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }

    func testAuthorizeResultReturnsSuccessForSuccessNode() {
        let user = MockSessionUser()
        let successNode = SuccessNode(input: [:], session: user)

        let result = OidcWebClient.authorizeResult(from: successNode)

        switch result {
        case .success(let returnedUser):
            XCTAssertTrue(returnedUser is MockSessionUser)
        case .failure(let error):
            XCTFail("Expected .success, got .failure(\(error))")
        }
    }

    func testAuthorizeResultReturnsUnknownForUnexpectedNode() {
        let result = OidcWebClient.authorizeResult(from: EmptyNode())

        switch result {
        case .failure(let error):
            guard case .unknown(let cause, let message) = error else {
                XCTFail("Expected .unknown, got \(error)")
                return
            }
            XCTAssertNil(cause)
            XCTAssertEqual(message, "Unexpected result")
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }

    // MARK: - End-to-end: authorize() preserves BrowserError.externalUserAgentCancelled (SDKS-5295)

    /// Drives the *entire* pipeline (`WebModule.transport` -> `Workflow.start(_:)` -> `FailureNode`
    /// -> `authorize()`), not just the extracted `authorizeResult(from:)` helper, to prove the
    /// browser-cancellation signal survives end-to-end. Discovery is stubbed via `MockURLProtocol`;
    /// the browser step is intercepted by `CancellingBrowser`, which throws
    /// `BrowserError.externalUserAgentCancelled` immediately instead of opening a real
    /// `ASWebAuthenticationSession`.
    @MainActor
    func testAuthorizeEndToEndPreservesExternalUserAgentCancelled() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }

        MockURLProtocol.requestHandler = { request in
            switch request.url!.path {
            case MockAPIEndpoint.discovery.url.path:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, MockResponse.openIdConfiguration)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }

        BrowserLauncher.currentBrowser = CancellingBrowser()

        let client = OidcWebClient.createOidcWebClient { config in
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "TestClientId"
                oidcValue.scopes = Set("openid profile email".split(separator: " ").map { String($0) })
                oidcValue.redirectUri = "https://example.com/callback"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
            }
        }

        let result = try await client.authorize()

        switch result {
        case .failure(let error):
            guard case .authorizeError(let cause, _) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            guard case .some(BrowserError.externalUserAgentCancelled) = cause as? BrowserError else {
                XCTFail("Expected cause to be BrowserError.externalUserAgentCancelled, got \(String(describing: cause))")
                return
            }
        case .success:
            XCTFail("Expected .failure, got .success")
        }
    }
}

// MARK: - Test Helpers

/// Intercepts `BrowserLauncher.currentBrowser.launch(...)` and immediately throws
/// `BrowserError.externalUserAgentCancelled`, simulating a user cancelling the
/// `ASWebAuthenticationSession` without opening a real browser. Mirrors `CapturingBrowser` in
/// `OidcWebClientE2ETests.swift`.
private final class CancellingBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var isInProgress: Bool = false

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        logger: PingLogger.Logger
    ) async throws -> URL {
        throw BrowserError.externalUserAgentCancelled
    }

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        redirectUri: String?,
        logger: PingLogger.Logger
    ) async throws -> URL {
        throw BrowserError.externalUserAgentCancelled
    }

    func reset() {}
    func handleAppActivation() {}
}

/// A minimal `User` + `Session` conformer used to exercise `SuccessNode.session as? User`
/// without pulling in the full `UserDelegate`/`OidcUser` machinery.
private struct MockSessionUser: User, Session {
    var value: String = "mock-session-value"

    func token() async -> Result<Token, OidcError> { .failure(.unknown()) }
    func refresh() async -> Result<Token, OidcError> { .failure(.unknown()) }
    func revoke() async {}
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> { .failure(.unknown()) }
    func logout() async {}
}
