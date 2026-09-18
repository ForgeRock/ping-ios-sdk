//
//  OidcClientRARTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


//  SDKS-5425 — RFC 9396 Rich Authorization Requests: first-class `authorizationDetails`
//  on the authorize surface with a PAR-safe per-transaction path.
//
//  Part of this file documents (and locks in) the still-accurate legacy pitfalls from the
//  SDKS-3895 spike: customParams / additionalParameters / per-login OidcOptions are applied
//  AFTER PAR population, so they never reach the PAR body and leak onto the front-channel
//  URL. The new typed `authorizationDetails` surface is the PAR-safe replacement.

import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage
@testable import PingOrchestrate
@testable import PingBrowser

/// Reusable body reader (mirrors the helper in OidcClientPARTests).
private func rarBodyData(from request: URLRequest) -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)
        if bytesRead > 0 {
            data.append(buffer, count: bytesRead)
        } else {
            break
        }
    }
    return data
}

final class OidcClientRARTests: XCTestCase {

    var oidcClientConfig: OidcClientConfig!

    static let parEndpointURL = URL(string: "\(MockAPIEndpoint.baseURL)/par")!

    /// OpenID configuration including the PAR endpoint (mirrors OidcClientPARTests).
    static var openIdConfigurationWithPAR: Data {
        """
        {
          "authorization_endpoint" : "\(MockAPIEndpoint.authorization.url.absoluteString)",
          "token_endpoint" : "\(MockAPIEndpoint.token.url.absoluteString)",
          "userinfo_endpoint" : "\(MockAPIEndpoint.userinfo.url.absoluteString)",
          "end_session_endpoint" : "\(MockAPIEndpoint.endSession.url.absoluteString)",
          "revocation_endpoint" : "\(MockAPIEndpoint.revocation.url.absoluteString)",
          "pushed_authorization_request_endpoint" : "\(parEndpointURL.absoluteString)"
        }
        """.data(using: .utf8)!
    }

    static var parResponse: Data {
        """
        {
          "request_uri" : "urn:ietf:params:oauth:request_uri:rar",
          "expires_in" : 60
        }
        """.data(using: .utf8)!
    }

    /// The RFC 9396 §2 `payment_initiation` example — the epic's "send a secure financial
    /// transaction" payload.
    static var paymentInitiationDetails: [AuthorizationDetail] {
        [
            AuthorizationDetail(
                type: "payment_initiation",
                locations: ["https://example.com/payments"],
                additionalFields: [
                    "instructedAmount": .object(["currency": .string("EUR"), "amount": .string("123.50")]),
                    "creditorName": .string("Merchant A"),
                    "creditorAccount": .object(["iban": .string("DE02100100109307118603")]),
                    "remittanceInformationUnstructured": .string("Ref Number Merchant")
                ]
            )
        ]
    }

    /// URL-decodes an `application/x-www-form-urlencoded` body into (name, value) pairs.
    private func formFields(ofBody body: Data) -> [(String, String)] {
        guard let bodyString = String(data: body, encoding: .utf8) else { return [] }
        var components = URLComponents()
        components.percentEncodedQuery = bodyString
        return (components.queryItems ?? []).map { ($0.name, $0.value ?? "") }
    }

    /// Extracts the raw (still URL-encoded) value of one query parameter from a URL string.
    private func rawQueryValue(named name: String, in urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let item = components.queryItems?.first(where: { $0.name == name }) else {
            return nil
        }
        return item.value
    }

    /// Counts occurrences of a query parameter name in a URL string.
    private func queryParamOccurrences(named name: String, in urlString: String) -> Int {
        guard let components = URLComponents(string: urlString) else { return 0 }
        return (components.queryItems ?? []).filter { $0.name == name }.count
    }

    override func setUp() {
        super.setUp()
        oidcClientConfig = OidcClientConfig()
        oidcClientConfig.clientId = "rar-client"
        oidcClientConfig.scopes = Set(["openid", "email"])
        oidcClientConfig.redirectUri = "http://localhost:8080/callback"
        oidcClientConfig.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        oidcClientConfig.storage = MockStorage<Token>()
        oidcClientConfig.httpClient = MockURLProtocol.makeClient()
        MockURLProtocol.startInterceptingRequests()
    }

    override func tearDown() {
        oidcClientConfig = nil
        MockURLProtocol.stopInterceptingRequests()
        super.tearDown()
    }

    /// Installs the standard discovery + PAR mock handler.
    private func installMockHandler() {
        MockURLProtocol.requestHandler = { [self] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientRARTests.openIdConfigurationWithPAR)
            case OidcClientRARTests.parEndpointURL.path:
                return (try mockResponse(url: OidcClientRARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientRARTests.parResponse)
            default:
                XCTFail("Unexpected request: \(request.url?.path ?? "<no url>")")
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
    }

    /// Like `installMockHandler()`, but also serves the revoke and token endpoints so the module
    /// pipeline's pre-login revoke (OidcModule.start) and post-callback token exchange (with the
    /// fake code from the capturing browser) complete instead of hitting the `XCTFail` default case.
    /// When `browser` is supplied, the PAR handler records the `state` from the PAR POST body on
    /// `browser.parSentState` so the double can echo it into the callback (PAR-mode state echo).
    private func installMockHandlerWithTokenEndpoint(browser: RarCapturingBrowser? = nil) {
        MockURLProtocol.requestHandler = { [self, browser] request in
            switch request.url?.path ?? "" {
            case MockAPIEndpoint.discovery.url.path:
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 200, headers: MockResponse.headers), OidcClientRARTests.openIdConfigurationWithPAR)
            case OidcClientRARTests.parEndpointURL.path:
                if let browser {
                    let body = String(data: rarBodyData(from: request), encoding: .utf8) ?? ""
                    var formComponents = URLComponents()
                    formComponents.percentEncodedQuery = body
                    browser.parSentState = formComponents.queryItems?.first { $0.name == OidcClient.Constants.state }?.value
                }
                return (try mockResponse(url: OidcClientRARTests.parEndpointURL, statusCode: 201, headers: MockResponse.headers), OidcClientRARTests.parResponse)
            case MockAPIEndpoint.token.url.path:
                return (try mockResponse(url: MockAPIEndpoint.token.url, statusCode: 200, headers: MockResponse.headers), MockResponse.tokenWithAuthorizationDetails)
            case MockAPIEndpoint.revocation.url.path:
                return (try mockResponse(url: MockAPIEndpoint.revocation.url, statusCode: 200, headers: MockResponse.headers), Data())
            default:
                XCTFail("Unexpected request: \(request.url?.path ?? "<no url>")")
                return (try mockResponse(url: MockAPIEndpoint.discovery.url, statusCode: 500), Data())
            }
        }
    }

    /// Creates an `HTTPURLResponse` or throws (mirrors OidcClientPARTests).
    private func mockResponse(url: URL, statusCode: Int, headers: [String: String]? = nil) throws -> HTTPURLResponse {
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: headers) else {
            throw URLError(.badServerResponse)
        }
        return response
    }

    // MARK: - New typed surface: config-level authorizationDetails

    /// Config-level typed `authorizationDetails` must reach the PAR POST body, and never
    /// land on the front-channel URL.
    func testConfigLevelAuthorizationDetailsReachesPARBody() async throws {
        oidcClientConfig.par = true
        oidcClientConfig.authorizationDetails = OidcClientRARTests.paymentInitiationDetails
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl()

        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2, "Expected discovery + PAR requests")
        let parRequest = MockURLProtocol.requestHistory[1]
        XCTAssertEqual(parRequest.httpMethod, "POST")
        let fields = formFields(ofBody: rarBodyData(from: parRequest))
        let sentValue = try XCTUnwrap(fields.first { $0.0 == OidcClient.Constants.authorization_details }?.1,
                                      "authorization_details must reach the PAR body")
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)

        // PAR mode: front-channel URL carries only request_uri + client_id.
        XCTAssertTrue(url.absoluteString.contains("request_uri="))
        XCTAssertFalse(url.absoluteString.contains("authorization_details"),
                       "authorization_details must stay in the PAR body, not on the authorize URL")
    }

    /// Config-level typed `authorizationDetails` on the standard (non-PAR) flow serializes
    /// correctly onto the front-channel URL, exactly once.
    func testConfigLevelAuthorizationDetailsOnStandardFlowUrl() async throws {
        oidcClientConfig.authorizationDetails = OidcClientRARTests.paymentInitiationDetails
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        let url = try await oidcClient.generateAuthorizeUrl()
        let urlString = url.absoluteString

        XCTAssertEqual(queryParamOccurrences(named: OidcClient.Constants.authorization_details, in: urlString), 1,
                       "authorization_details must appear exactly once on the URL")
        let sentValue = try XCTUnwrap(rawQueryValue(named: OidcClient.Constants.authorization_details, in: urlString))
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)
    }

    /// The new `authorizationDetails:` named parameter on the async PAR-capable overload must
    /// reach the PAR body — in contrast to `customParams`, which (documented, unchanged) is
    /// applied after PAR population and never reaches it.
    func testAuthorizationDetailsParameterReachesPARBody() async throws {
        oidcClientConfig.par = true
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        _ = try await oidcClient.generateAuthorizeUrl(authorizationDetails: OidcClientRARTests.paymentInitiationDetails)

        XCTAssertEqual(MockURLProtocol.requestHistory.count, 2, "Expected discovery + PAR requests")
        let parRequest = MockURLProtocol.requestHistory[1]
        let fields = formFields(ofBody: rarBodyData(from: parRequest))
        let sentValue = try XCTUnwrap(fields.first { $0.0 == OidcClient.Constants.authorization_details }?.1,
                                      "authorization_details parameter must reach the PAR body")
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)
    }

    /// The sync overload also accepts `authorizationDetails:` — no PAR to protect there, so the
    /// serialized value lands on the front-channel URL (same as customParams today).
    func testAuthorizationDetailsParameterOnSyncOverload() async throws {
        installMockHandler()
        // The sync overload never initializes discovery itself (it is fully synchronous), so
        // populate the OpenID configuration explicitly first.
        try await oidcClientConfig.oidcInitialize()

        let oidcClient = OidcClient(config: oidcClientConfig)
        // Explicitly typed as the non-async signature: an unqualified call from this async
        // context would resolve to the async overload instead (same pattern as OidcClientPARTests).
        let syncGenerateAuthorizeUrl: ([String: String]?, [AuthorizationDetail]?) throws -> URL = oidcClient.generateAuthorizeUrl
        let url = try syncGenerateAuthorizeUrl(nil, OidcClientRARTests.paymentInitiationDetails)
        let urlString = url.absoluteString

        XCTAssertEqual(queryParamOccurrences(named: OidcClient.Constants.authorization_details, in: urlString), 1)
        let sentValue = try XCTUnwrap(rawQueryValue(named: OidcClient.Constants.authorization_details, in: urlString))
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)
    }

    /// Per-transaction `extraParameters` carrying `authorization_details` wins over the
    /// config-level typed value, and the key is emitted at most once (Request.setParameter
    /// APPENDS on a repeated key — a second emission would duplicate the query parameter).
    func testExtraParametersAuthorizationDetailsWinOverConfigLevelExactlyOnce() async throws {
        let configDetails = [AuthorizationDetail(type: "account_information", actions: ["read"])]
        let transactionDetails = OidcClientRARTests.paymentInitiationDetails

        oidcClientConfig.par = false
        oidcClientConfig.authorizationDetails = configDetails
        installMockHandler()
        // populateRequest needs a materialized OpenID configuration (authorization endpoint),
        // so run discovery explicitly — populateRequest itself does not initialize.
        try await oidcClientConfig.oidcInitialize()

        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient)
        let request = httpClient.request()
        let pkce = Pkce.generate()
        _ = try await oidcClientConfig.populateRequest(
            request: request,
            pkce: pkce,
            responseMode: OidcClient.Constants.query,
            extraParameters: [OidcClient.Constants.authorization_details: try AuthorizationDetail.wireValue(transactionDetails)]
        )

        let urlString = try XCTUnwrap(request.url)
        XCTAssertEqual(queryParamOccurrences(named: OidcClient.Constants.authorization_details, in: urlString), 1,
                       "authorization_details must be emitted at most once even when both config-level and per-transaction values exist")
        let sentValue = try XCTUnwrap(rawQueryValue(named: OidcClient.Constants.authorization_details, in: urlString))
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, transactionDetails, "the per-transaction value must win over the config-level value")
        XCTAssertFalse(urlString.contains("account_information"),
                       "the config-level value must not appear when a per-transaction value is present")
    }

    /// Direct `populateRequest(extraParameters:)` test: non-RAR extra parameters ride along
    /// into the PAR body alongside everything else.
    func testPopulateRequestForwardsExtraParametersIntoPARBody() async throws {
        oidcClientConfig.par = true
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        _ = try await oidcClient.generateAuthorizeUrl()

        MockURLProtocol.requestHistory.removeAll()

        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient)
        let request = httpClient.request()
        _ = try await oidcClientConfig.populateRequest(
            request: request,
            pkce: Pkce.generate(),
            responseMode: OidcClient.Constants.query,
            extraParameters: ["custom_param": "custom_value"]
        )

        let parRequests = MockURLProtocol.requestHistory.filter { $0.url?.path == OidcClientRARTests.parEndpointURL.path }
        XCTAssertEqual(parRequests.count, 1)
        let fields = formFields(ofBody: rarBodyData(from: parRequests[0]))
        XCTAssertEqual(fields.first { $0.0 == "custom_param" }?.1, "custom_value",
                       "extraParameters must be forwarded into the PAR body")
    }

    // MARK: - Legacy pitfalls (locked in, still accurate by design)

    /// `generateAuthorizeUrl(customParams:)` applies custom params to the URL *after* the PAR
    /// round-trip, so with PAR enabled `authorization_details` passed via customParams:
    ///  - never reaches the PAR POST body (the server never binds it to the transaction), and
    ///  - is emitted onto the front-channel query string anyway (payload size / privacy leak).
    /// Documented behavior — this is precisely why the typed `authorizationDetails:` parameter
    /// exists as the PAR-safe alternative.
    func testAuthorizationDetailsViaCustomParamsDoesNotReachPARBody() async throws {
        oidcClientConfig.par = true
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        let customValue = try AuthorizationDetail.wireValue(OidcClientRARTests.paymentInitiationDetails)
        let url = try await oidcClient.generateAuthorizeUrl(customParams: [
            OidcClient.Constants.authorization_details: customValue
        ])
        let urlString = url.absoluteString

        let parRequest = MockURLProtocol.requestHistory[1]
        let fields = formFields(ofBody: parRequest.httpBody ?? Data())
        XCTAssertNil(fields.first { $0.0 == OidcClient.Constants.authorization_details },
                     "customParams are not forwarded into the PAR body (documented behavior)")

        XCTAssertNotNil(rawQueryValue(named: OidcClient.Constants.authorization_details, in: urlString),
                        "customParams always end up on the front-channel query string, even in PAR mode")
    }

    /// Per-login `OidcOptions.additionalParameters` behave like customParams (applied after
    /// PAR population in OidcModule.start) — the same legacy pitfall, locked in. The typed
    /// `OidcOptions.authorizationDetails` field is the PAR-safe replacement.
    func testPerLoginOptionsAdditionalParametersAreAppliedAfterPARPopulation() async throws {
        oidcClientConfig.par = true
        installMockHandler()

        let oidcClient = OidcClient(config: oidcClientConfig)
        _ = try await oidcClient.generateAuthorizeUrl() // let discovery + PAR happen once
        MockURLProtocol.requestHistory.removeAll()

        // Simulate OidcModule.start: PAR-populate, then apply per-login options afterwards.
        let httpClient = try XCTUnwrap(oidcClientConfig.httpClient)
        var request = httpClient.request()
        let pkce = Pkce.generate()
        request = try await oidcClientConfig.populateRequest(request: request, pkce: pkce, responseMode: "")

        let perLoginOptions: [String: String] = [
            OidcClient.Constants.authorization_details: try AuthorizationDetail.wireValue(OidcClientRARTests.paymentInitiationDetails)
        ]
        for parameter in perLoginOptions {
            request.setParameter(name: parameter.key, value: parameter.value)
        }

        let parRequests = MockURLProtocol.requestHistory.filter { $0.url?.path == OidcClientRARTests.parEndpointURL.path }
        XCTAssertEqual(parRequests.count, 1)
        let fields = formFields(ofBody: rarBodyData(from: parRequests[0]))
        XCTAssertNil(fields.first { $0.0 == OidcClient.Constants.authorization_details },
                     "Per-login additionalParameters are applied after PAR population (documented pitfall)")
        let urlString = try XCTUnwrap(request.url)
        XCTAssertNotNil(rawQueryValue(named: OidcClient.Constants.authorization_details, in: urlString),
                        "Per-login authorization_details ends up on the front-channel URL when PAR is enabled")
    }

    // MARK: - End-to-end through the real OidcModule pipeline (OidcOptions → PAR body)

    /// Drives the REAL pipeline — `createOidcWebClient` → `authorize { options in ... }` →
    /// `OidcWebClient.startOidcLogin` (sharedContext write) → `OidcModule.start` (sharedContext
    /// read + serialize + extraParameters) → `populateRequest` (PAR round-trip) — not a hand
    /// simulation. The browser step is intercepted, so no real ASWebAuthenticationSession opens.
    @MainActor
    func testOidcOptionsAuthorizationDetailsReachesPARBodyThroughModulePipeline() async throws {
        let browser = RarCapturingBrowser()
        installMockHandlerWithTokenEndpoint(browser: browser)
        BrowserLauncher.currentBrowser = browser
        defer { BrowserLauncher.currentBrowser = BrowserLauncher() }

        let web = OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "rar-module-client"
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "http://localhost:8080/callback"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
                oidcValue.par = true
            }
        }

        // The token exchange after the browser callback completes (the double echoes the
        // PAR-body state) fails with the fake code — expected; everything under test (the
        // PAR POST) has already happened by then.
        do {
            _ = try await web.authorize { options in
                options.authorizationDetails = OidcClientRARTests.paymentInitiationDetails
            }
        } catch { /* fake code fails token exchange — expected */ }

        let parRequests = MockURLProtocol.requestHistory.filter { $0.url?.path == OidcClientRARTests.parEndpointURL.path }
        XCTAssertEqual(parRequests.count, 1, "Expected exactly one PAR request through the module pipeline")
        let fields = formFields(ofBody: rarBodyData(from: parRequests[0]))
        let sentValue = try XCTUnwrap(fields.first { $0.0 == OidcClient.Constants.authorization_details }?.1,
                                      "Per-transaction OidcOptions.authorizationDetails must reach the PAR body through the real OidcModule.start path")
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)

        // And the front-channel URL the browser received carries only request_uri + client_id.
        let launched = try XCTUnwrap(browser.launchedURL)
        XCTAssertTrue(launched.absoluteString.contains("request_uri="))
        XCTAssertFalse(launched.absoluteString.contains("authorization_details"),
                       "The browser URL must not carry authorization_details in PAR mode")
    }

    /// Same module pipeline with `par = false`: the per-transaction details land on the
    /// front-channel URL exactly once.
    @MainActor
    func testOidcOptionsAuthorizationDetailsOnFrontChannelThroughModulePipeline() async throws {
        let browser = RarCapturingBrowser()
        installMockHandlerWithTokenEndpoint(browser: browser)
        BrowserLauncher.currentBrowser = browser
        defer { BrowserLauncher.currentBrowser = BrowserLauncher() }

        let web = OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "rar-module-client"
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "http://localhost:8080/callback"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
                // par defaults to false
            }
        }

        do {
            _ = try await web.authorize { options in
                options.authorizationDetails = OidcClientRARTests.paymentInitiationDetails
            }
        } catch { /* fake code fails token exchange — expected */ }

        let parRequests = MockURLProtocol.requestHistory.filter { $0.url?.path == OidcClientRARTests.parEndpointURL.path }
        XCTAssertTrue(parRequests.isEmpty, "No PAR request expected when par = false")

        let launched = try XCTUnwrap(browser.launchedURL, "Browser was not launched")
        XCTAssertEqual(queryParamOccurrences(named: OidcClient.Constants.authorization_details, in: launched.absoluteString), 1,
                       "authorization_details must appear exactly once on the front-channel URL")
        let sentValue = try XCTUnwrap(rawQueryValue(named: OidcClient.Constants.authorization_details, in: launched.absoluteString))
        let decoded = try JSONDecoder().decode([AuthorizationDetail].self, from: Data(sentValue.utf8))
        XCTAssertEqual(decoded, OidcClientRARTests.paymentInitiationDetails)
    }

    // MARK: - State override is threaded through the PAR body (Module/Oidc.swift → buildAuthorizeParams)

    /// Regression test for the "at most once" state-threading fix: an
    /// `additionalParameters["state"]` override is now routed through the SAME
    /// `extraParameters` slot `authorization_details` already used, rather than appended
    /// post-hoc onto the front-channel URL. As a result the override reaches the PAR POST
    /// body — a PAR-supporting AS correctly echoes the override value, `Module/Oidc.swift`
    /// records exactly that as the expected callback state, and the two agree.
    ///
    /// `RarCapturingBrowser` models a spec-compliant AS: it echoes `parSentState` (the state
    /// it actually saw in the mocked PAR POST body).
    @MainActor
    func testAdditionalParametersStateOverrideReachesPARBodyAndValidatesCorrectly() async throws {
        let browser = RarCapturingBrowser()
        installMockHandlerWithTokenEndpoint(browser: browser)
        BrowserLauncher.currentBrowser = browser
        defer { BrowserLauncher.currentBrowser = BrowserLauncher() }

        let web = OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "rar-module-client"
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "http://localhost:8080/callback"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
                oidcValue.par = true
            }
        }

        let result = try await web.authorize { options in
            options.additionalParameters["state"] = "integrator-override"
        }

        // The override reached the PAR body — confirm directly on the mocked PAR request.
        let parRequests = MockURLProtocol.requestHistory.filter { $0.url?.path == OidcClientRARTests.parEndpointURL.path }
        let parRequest = try XCTUnwrap(parRequests.first, "Expected a PAR request")
        let fields = formFields(ofBody: rarBodyData(from: parRequest))
        let sentState = fields.first { $0.0 == OidcClient.Constants.state }?.1
        XCTAssertEqual(sentState, "integrator-override", "additionalParameters's state override must reach the PAR POST body")

        // And it must NOT additionally leak onto the front-channel URL — threaded through
        // extraParameters like authorization_details, not appended post-hoc.
        let launched = try XCTUnwrap(browser.launchedURL)
        XCTAssertFalse(launched.absoluteString.contains("state="),
                       "The state override must not leak onto the front-channel URL under PAR")

        // The AS echoes the override (it's the value actually pushed to the PAR endpoint),
        // and the recorded expectation matches it — the callback must be accepted.
        if case .failure(let error) = result, case .authorizeError(_, let message) = error {
            XCTAssertFalse(message?.contains("State mismatch") ?? false,
                           "Callback echoing the correctly-threaded override state must not be rejected: \(String(describing: message))")
        }
    }
}

/// Minimal browser double for the module-pipeline RAR tests (mirrors `CapturingBrowser` in
/// `OidcWebClientE2ETests.swift`, file-private there, so re-declared here).
///
/// Echoes the `state` the SDK sent into the callback URL, mirroring a real authorization
/// server — the transport's CSRF state validation (RFC 6749 §10.12) rejects a fixed
/// `state=fake` fixture. Two sources, because the state location differs by flow:
/// - Query mode: the `state` query item on the launched authorize URL.
/// - PAR mode: the authorize URL carries no state (only `request_uri`), so the double
///   records the `state` it saw in the PAR POST body (its `parSentState` property is set
///   by the test's mock handler) and echoes that.
private final class RarCapturingBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var launchedURL: URL?
    var isInProgress: Bool = false
    var callbackURL: URL = URL(string: "http://localhost:8080/callback?code=fake-code&state=fake")!
    /// Lock-protected `parSentState`: mutated by the (nonisolated) mock PAR handler and
    /// read by `launch` on the main actor. `nonisolated(unsafe)` + NSLock because the
    /// class is MainActor-inferred via the @MainActor `BrowserLauncherProtocol` conformance,
    /// while the mock-handler closure is nonisolated — the same pattern as
    /// `MockURLProtocol.requestHandler`.
    // `NSLock` is itself `Sendable`, so the constant needs no `nonisolated(unsafe)`; only
    // the mutable `String?` it guards does.
    private let stateLock = NSLock()
    private nonisolated(unsafe) var sentState: String?

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        logger: PingLogger.Logger
    ) async throws -> URL {
        launchedURL = url
        return callbackResponse(url: url)
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
        return callbackResponse(url: url)
    }

    /// The `state` from the last mocked PAR POST body, set by the test's PAR handler when
    /// PAR mode is under test (nil in query mode).
    nonisolated var parSentState: String? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return sentState }
        set { stateLock.lock(); sentState = newValue; stateLock.unlock() }
    }

    /// Builds the callback URL: substitutes the state the SDK sent for the fixture's
    /// `state=fake`, preserving everything else on `callbackURL` (notably the code).
    private func callbackResponse(url: URL) -> URL {
        // `parSentState` (the PAR-body state) takes priority over any `state` on the
        // launched URL: a PAR-compliant AS resolves the authorization request server-side
        // from the pushed `request_uri` and ignores stray front-channel query params. In
        // practice under PAR the launched URL never carries `state` at all — `state` is
        // threaded through the at-most-once `extraParameters` slot into the PAR body only,
        // same as `authorization_details` — so this fallback exists for the non-PAR flow,
        // where the URL's `state` IS the authoritative sent value.
        let sentState = parSentState ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "state" })?.value
        guard let sentState else { return callbackURL }
        var components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)!
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "state" }
        items.append(URLQueryItem(name: "state", value: sentState))
        components.queryItems = items
        return components.url ?? callbackURL
    }

    func reset() {}
    func handleAppActivation() {}
}
