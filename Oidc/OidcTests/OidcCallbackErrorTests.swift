//
//  OidcCallbackErrorTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


//  OAuth2 authorization-redirect error surfacing + state validation:
//  - extractOAuthError parses `error`/`error_description`/`error_uri` from query or fragment.
//  - validateState enforces the CSRF state check on the browser callback.
//  - extractCodeAndGetToken surfaces `access_denied` instead of a generic "code not found".

import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage
@testable import PingBrowser

final class OidcCallbackErrorTests: XCTestCase {

    // MARK: - extractOAuthError (query)

    func testExtractOAuthErrorFromQueryString() throws {
        let url = URL(string: "myapp://oauth2redirect?error=access_denied&error_description=The%20user%20denied%20the%20request&error_uri=https%3A%2F%2Fexample.com%2Fdocs")!
        let error = try XCTUnwrap(OidcClient.extractOAuthError(from: url))
        XCTAssertEqual(error.code, "access_denied")
        XCTAssertEqual(error.errorDescription, "The user denied the request")
        XCTAssertEqual(error.errorUri, "https://example.com/docs")
    }

    func testExtractOAuthErrorFromFragment() throws {
        let url = URL(string: "myapp://oauth2redirect#error=invalid_request&error_description=Duplicate%20parameter")!
        let error = try XCTUnwrap(OidcClient.extractOAuthError(from: url))
        XCTAssertEqual(error.code, "invalid_request")
        XCTAssertEqual(error.errorDescription, "Duplicate parameter")
    }

    func testExtractOAuthErrorMinimalErrorOnly() throws {
        let url = URL(string: "myapp://oauth2redirect?error=access_denied")!
        let error = try XCTUnwrap(OidcClient.extractOAuthError(from: url))
        XCTAssertEqual(error.code, "access_denied")
        XCTAssertNil(error.errorDescription)
        XCTAssertNil(error.errorUri)
    }

    func testExtractOAuthErrorNilForSuccessRedirect() throws {
        let url = URL(string: "myapp://oauth2redirect?code=abc&state=xyz")!
        XCTAssertNil(OidcClient.extractOAuthError(from: url))
    }

    func testExtractOAuthErrorNilForPlainURL() throws {
        let url = URL(string: "myapp://oauth2redirect")!
        XCTAssertNil(OidcClient.extractOAuthError(from: url))
    }

    /// An error takes precedence over a code when (unusually) both are present.
    func testExtractOAuthErrorTakesPrecedenceOverCode() throws {
        let url = URL(string: "myapp://oauth2redirect?code=abc&error=server_error")!
        let error = try XCTUnwrap(OidcClient.extractOAuthError(from: url))
        XCTAssertEqual(error.code, "server_error")
    }

    // MARK: - extractCodeAndGetToken surfaces the OAuth2 error

    func testExtractCodeAndGetTokenThrowsOAuthErrorForAccessDenied() async {
        let config = OidcClientConfig()
        config.clientId = "test-client"
        let client = OidcClient(config: config)

        let url = URL(string: "myapp://oauth2redirect?error=access_denied&error_description=User%20declined%20consent")!
        do {
            _ = try await client.extractCodeAndGetToken(from: url)
            XCTFail("Expected an error for an error redirect")
        } catch let error as OidcError {
            guard case .authorizeError(let cause, let message) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            guard let oauthError = cause as? OAuthAuthorizationError else {
                XCTFail("Expected cause to be OAuthAuthorizationError, got \(String(describing: cause))")
                return
            }
            XCTAssertEqual(oauthError.code, "access_denied")
            XCTAssertEqual(oauthError.errorDescription, "User declined consent")
            XCTAssertEqual(message, "Authorization failed: access_denied: User declined consent")
        } catch {
            XCTFail("Expected OidcError, got \(error)")
        }
    }

    /// Regression test: `extractCodeAndGetToken` must validate against the value actually
    /// sent on the wire (`config.state ?? pkce.state`, matching `buildAuthorizeParams`'s
    /// precedence) — not unconditionally against `pkce.state`. When `OidcClientConfig.state`
    /// is set, the AS echoes THAT value, not the PKCE-generated one; validating against
    /// `pkce.state` alone would reject every legitimate callback for such integrators.
    func testExtractCodeAndGetTokenValidatesAgainstConfigStateWhenSet() async {
        let config = OidcClientConfig()
        config.clientId = "test-client"
        config.state = "integrator-state"
        let client = OidcClient(config: config)
        client.pkce = Pkce.generate() // a different, randomly-generated state

        // The AS echoes config.state (the value actually sent) — not pkce.state.
        let url = URL(string: "myapp://oauth2redirect?code=fake-code&state=integrator-state")!
        do {
            _ = try await client.extractCodeAndGetToken(from: url)
            // Token exchange itself may fail (no mock endpoint configured) — that's fine;
            // the point of this test is that it must NOT fail with a state mismatch.
        } catch let error as OidcError {
            if case .authorizeError(_, let message) = error {
                XCTAssertFalse(message?.contains("State mismatch") ?? false,
                               "Must not reject a callback whose state matches config.state: \(String(describing: message))")
            }
        } catch {
            // Non-OidcError failures (e.g. network) are acceptable — state validation
            // already passed by the time execution could reach one.
        }
    }

    /// Companion to the test above: a callback echoing the (never-sent) `pkce.state`
    /// instead of `config.state` must be rejected — `config.state` takes precedence,
    /// matching what `buildAuthorizeParams` actually put on the wire.
    func testExtractCodeAndGetTokenRejectsPkceStateWhenConfigStateIsSet() async {
        let config = OidcClientConfig()
        config.clientId = "test-client"
        config.state = "integrator-state"
        let client = OidcClient(config: config)
        let pkce = Pkce.generate()
        client.pkce = pkce

        let url = URL(string: "myapp://oauth2redirect?code=fake-code&state=\(pkce.state)")!
        do {
            _ = try await client.extractCodeAndGetToken(from: url)
            XCTFail("Expected a state mismatch — the AS never actually sent pkce.state")
        } catch let error as OidcError {
            guard case .authorizeError(_, let message) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            XCTAssertTrue(message?.contains("State mismatch") ?? false, "Unexpected message: \(String(describing: message))")
        } catch {
            XCTFail("Expected OidcError, got \(error)")
        }
    }

    // MARK: - validateState

    func testValidateStateAcceptsMatchingState() throws {
        let url = URL(string: "myapp://oauth2redirect?code=abc&state=expected-state")!
        XCTAssertNoThrow(try WebModule.validateState(from: url, expected: "expected-state"))
    }

    func testValidateStateThrowsOnMismatch() {
        let url = URL(string: "myapp://oauth2redirect?code=abc&state=evil-state")!
        XCTAssertThrowsError(try WebModule.validateState(from: url, expected: "expected-state")) { error in
            guard case OidcError.authorizeError(_, let message) = error else {
                XCTFail("Expected .authorizeError, got \(error)")
                return
            }
            XCTAssertTrue(message?.contains("State mismatch") ?? false, "Unexpected message: \(String(describing: message))")
        }
    }

    func testValidateStateThrowsWhenStateMissingButExpected() {
        let url = URL(string: "myapp://oauth2redirect?code=abc")!
        XCTAssertThrowsError(try WebModule.validateState(from: url, expected: "expected-state"))
    }

    /// No expected value recorded → validation is skipped (back-compat for paths that
    /// never registered a state).
    func testValidateStateSkippedWhenExpectedNil() throws {
        let url = URL(string: "myapp://oauth2redirect?code=abc")!
        XCTAssertNoThrow(try WebModule.validateState(from: url, expected: nil))
    }

    // MARK: - End-to-end: module pipeline surfaces access_denied through authorize()

    /// Drives the real `WebModule.transport` path with a browser double that returns an
    /// `access_denied` redirect: the integrator must receive `OidcError.authorizeError`
    /// whose cause is the typed `OAuthAuthorizationError`, not "Authorization code not found".
    @MainActor
    func testModulePipelineSurfacesAccessDeniedFromCallback() async throws {
        MockURLProtocol.startInterceptingRequests()
        defer { MockURLProtocol.stopInterceptingRequests() }
        MockURLProtocol.requestHandler = { request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                let discovery = """
                {
                  "authorization_endpoint" : "\(MockAPIEndpoint.authorization.url.absoluteString)",
                  "token_endpoint" : "\(MockAPIEndpoint.token.url.absoluteString)",
                  "userinfo_endpoint" : "\(MockAPIEndpoint.userinfo.url.absoluteString)",
                  "end_session_endpoint" : "\(MockAPIEndpoint.endSession.url.absoluteString)",
                  "revocation_endpoint" : "\(MockAPIEndpoint.revocation.url.absoluteString)"
                }
                """.data(using: .utf8)!
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, httpVersion: nil, headerFields: MockResponse.headers)!, discovery)
            default:
                return (HTTPURLResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
        }
        BrowserLauncher.currentBrowser = AccessDeniedBrowser()
        defer { BrowserLauncher.currentBrowser = BrowserLauncher() }

        let web = OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "callback-error-client"
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "http://localhost:8080/callback"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
            }
        }

        let result = try await web.authorize { options in
            // The browser double returns a fixed access-denied callback below.
        }

        guard case .failure(.authorizeError(let cause, _)) = result else {
            XCTFail("Expected .authorizeError failure, got \(result)")
            return
        }
        let oauthError = try XCTUnwrap(cause as? OAuthAuthorizationError,
                                       "Expected cause to be OAuthAuthorizationError, got \(String(describing: cause))")
        XCTAssertEqual(oauthError.code, "access_denied")
    }
}

/// Browser double that simulates the user declining consent: the callback carries an
/// OAuth2 `access_denied` error redirect (mirrors `CapturingBrowser` in the E2E tests).
@MainActor
private final class AccessDeniedBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var isInProgress: Bool = false
    var launchedURL: URL?

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        logger: PingLogger.Logger
    ) async throws -> URL {
        launchedURL = url
        return URL(string: "http://localhost:8080/callback?error=access_denied&error_description=User%20declined%20consent")!
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
        launchedURL = url
        return URL(string: "http://localhost:8080/callback?error=access_denied&error_description=User%20declined%20consent")!
    }

    func reset() {}
    func handleAppActivation() {}
}
