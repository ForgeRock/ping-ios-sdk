//
//  OidcMultiTokenTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


//  Holding several tokens at once (RFC 9396 RAR alongside an existing login).
//
//  Each workflow keeps ONE token in its own `storage`, and starting an authorization on a
//  browser-based workflow (OidcWebClient, as below) revokes and replaces the token in that
//  storage. These tests prove that giving the RAR login its own workflow and its own storage
//  covers both supported scenarios, with no live tenant:
//
//    Scenario 1: native login (Token A)  -> browser RAR (Token B)
//    Scenario 2: browser login (Token A) -> browser RAR (Token B)
//
//  For each: both tokens coexist and are usable, revoking B leaves A untouched, and logging out
//  takes one `logout()` per workflow. The last group documents why the separation matters, by
//  showing what happens when two workflows share one storage slot.
//
//  Everything below the test class is a test double: a fake authorization server (token,
//  revocation and end-session endpoints, with per-client token ownership), a fake browser that
//  completes the authorize redirect, and a stub native-login agent (standing in for a Journey
//  or DaVinci login, whose module wiring is covered by those modules' own tests).

import XCTest
@testable import PingOidc
@testable import PingNetwork
@testable import PingLogger
@testable import PingStorage
@testable import PingBrowser

@MainActor
final class OidcMultiTokenTests: XCTestCase {

    private var server: FakeAuthorizationServer!

    override func setUp() async throws {
        try await super.setUp()
        let server = FakeAuthorizationServer()
        self.server = server
        MockURLProtocol.startInterceptingRequests()
        MockURLProtocol.requestHandler = { request in try server.handle(request) }
        BrowserLauncher.currentBrowser = FakeBrowser(server: server)
    }

    override func tearDown() async throws {
        BrowserLauncher.currentBrowser = BrowserLauncher()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.stopInterceptingRequests()
        server = nil
        try await super.tearDown()
    }

    // MARK: - Scenario 1: native login, then browser RAR

    func testScenario1NativeThenRarTokensCoexist() async throws {
        try await assertTokensCoexist(primary: .native)
    }

    func testScenario1NativeThenRarSelectiveRevokeLeavesTokenAUntouched() async throws {
        try await assertSelectiveRevokeLeavesPrimaryUntouched(primary: .native)
    }

    func testScenario1NativeThenRarLogoutTakesOneCallPerWorkflow() async throws {
        try await assertLogoutTakesOneCallPerWorkflow(primary: .native)
    }

    // MARK: - Scenario 2: browser login, then browser RAR

    func testScenario2BrowserThenRarTokensCoexist() async throws {
        try await assertTokensCoexist(primary: .browser)
    }

    func testScenario2BrowserThenRarSelectiveRevokeLeavesTokenAUntouched() async throws {
        try await assertSelectiveRevokeLeavesPrimaryUntouched(primary: .browser)
    }

    func testScenario2BrowserThenRarLogoutTakesOneCallPerWorkflow() async throws {
        try await assertLogoutTakesOneCallPerWorkflow(primary: .browser)
    }

    /// The same OAuth client can back both the login and the RAR workflow; separation comes
    /// from the storage, not from the client.
    func testScenario2SameOAuthClientForBothWorkflowsStillKeepsBothTokens() async throws {
        let setup = try await signInThenRar(primary: .browser, primaryClientId: "sharedClient", rarClientId: "sharedClient")

        let tokenA = try await setup.primaryUser.token().get()
        let tokenB = try await setup.rarUser.token().get()

        XCTAssertNotEqual(tokenA.accessToken, tokenB.accessToken)
        XCTAssertTrue(server.calls(to: .revocation).isEmpty, "Starting the RAR login must not revoke Token A")
        XCTAssertFalse(server.isRevoked(tokenA.accessToken))
        XCTAssertFalse(server.isRevoked(tokenB.accessToken))
    }

    // MARK: - One token per workflow

    /// A workflow holds a single token: a second login on the same RAR workflow revokes and
    /// replaces its own previous token. Token A, held by a different workflow, is unaffected.
    func testSecondLoginOnTheSameRarWorkflowReplacesOnlyItsOwnToken() async throws {
        let setup = try await signInThenRar(primary: .browser)
        let tokenA = try await setup.primaryUser.token().get()
        let firstRarToken = try await setup.rarUser.token().get()

        let secondPayment = Self.payment(amount: "10.00")
        let secondUser = try await setup.rarWorkflow.authorize { options in
            options.authorizationDetails = [secondPayment]
        }.get()
        let secondRarToken = try await secondUser.token().get()

        XCTAssertNotEqual(firstRarToken.accessToken, secondRarToken.accessToken)
        XCTAssertTrue(server.isRevoked(firstRarToken.accessToken), "The RAR workflow revokes its own previous token")
        XCTAssertFalse(server.isRevoked(secondRarToken.accessToken))
        XCTAssertFalse(server.isRevoked(tokenA.accessToken), "Token A belongs to another workflow")

        let revocations = server.calls(to: .revocation)
        XCTAssertEqual(revocations.count, 1)
        XCTAssertEqual(revocations.first?.fields["token"], firstRarToken.refreshToken)
        XCTAssertEqual(revocations.first?.fields["client_id"], setup.rarClientId)

        let storedRar = try await setup.rarStorage.get()
        XCTAssertEqual(storedRar?.accessToken, secondRarToken.accessToken)
        let storedPrimary = try await setup.primaryStorage.get()
        XCTAssertEqual(storedPrimary?.accessToken, tokenA.accessToken)
    }

    // MARK: - Shared storage (unsupported): why each workflow needs its own

    /// Two workflows that share one storage slot behave as one: the RAR login revokes Token A
    /// and takes its place, and the original workflow then hands out Token B.
    func testSharedStorageWithSameClientMakesTheRarLoginRevokeTokenA() async throws {
        let shared = MockStorage<Token>()
        let loginWorkflow = makeWebClient(clientId: "iosClient", storage: shared)
        let userA = try await loginWorkflow.authorize().get()
        let tokenA = try await userA.token().get()

        let rarWorkflow = makeWebClient(clientId: "iosClient", storage: shared)
        let details = [Self.payment()]
        let userB = try await rarWorkflow.authorize { options in
            options.authorizationDetails = details
        }.get()
        let tokenB = try await userB.token().get()

        XCTAssertTrue(server.isRevoked(tokenA.accessToken), "The RAR login revoked the token found in the shared slot")
        let revocation = try XCTUnwrap(server.calls(to: .revocation).first)
        XCTAssertEqual(revocation.fields["token"], tokenA.refreshToken)
        XCTAssertEqual(revocation.fields["client_id"], "iosClient")

        let stored = try await shared.get()
        XCTAssertEqual(stored?.accessToken, tokenB.accessToken)
        let servedToOriginalWorkflow = try await userA.token().get()
        XCTAssertEqual(servedToOriginalWorkflow.accessToken, tokenB.accessToken)
    }

    /// With different OAuth clients the revocation goes out under the RAR client's `client_id`
    /// for a token issued to another client. Per RFC 7009 §2.1 the server refuses it (modeled
    /// by the fake server), so Token A is deleted from the device yet stays valid at the
    /// server, and the original workflow now serves a token issued to a different client.
    func testSharedStorageWithDifferentClientsLosesTokenALocallyAndLeavesItValidAtTheServer() async throws {
        let shared = MockStorage<Token>()
        let loginWorkflow = makeWebClient(clientId: "iosClient", storage: shared)
        let userA = try await loginWorkflow.authorize().get()
        let tokenA = try await userA.token().get()

        let rarWorkflow = makeWebClient(clientId: "rarClient", storage: shared)
        let details = [Self.payment()]
        let userB = try await rarWorkflow.authorize { options in
            options.authorizationDetails = details
        }.get()
        let tokenB = try await userB.token().get()

        let revocation = try XCTUnwrap(server.calls(to: .revocation).first)
        XCTAssertEqual(revocation.fields["token"], tokenA.refreshToken)
        XCTAssertEqual(revocation.fields["client_id"], "rarClient", "Sent under the RAR client, not the client Token A was issued to")
        XCTAssertFalse(server.isRevoked(tokenA.accessToken), "The server refuses to revoke another client's token")

        let stored = try await shared.get()
        XCTAssertEqual(stored?.accessToken, tokenB.accessToken, "Token A is gone from the device")
        let servedToOriginalWorkflow = try await userA.token().get()
        XCTAssertTrue(servedToOriginalWorkflow.accessToken.hasPrefix("AT-rarClient"),
                      "The original workflow now returns a token issued to the RAR client")
    }

    // MARK: - Shared assertions

    private func assertTokensCoexist(primary: PrimaryLogin) async throws {
        let setup = try await signInThenRar(primary: primary)

        let tokenA = try await setup.primaryUser.token().get()
        let tokenB = try await setup.rarUser.token().get()

        XCTAssertNotEqual(tokenA.accessToken, tokenB.accessToken)
        XCTAssertTrue(tokenA.accessToken.hasPrefix("AT-\(setup.primaryClientId)"))
        XCTAssertTrue(tokenB.accessToken.hasPrefix("AT-\(setup.rarClientId)"))
        XCTAssertNil(tokenA.authorizationDetails, "Token A was issued without authorization_details")
        XCTAssertEqual(tokenB.authorizationDetails?.first?.type, "payment_initiation", "Token B carries the granted details")

        let storedA = try await setup.primaryStorage.get()
        let storedB = try await setup.rarStorage.get()
        XCTAssertEqual(storedA?.accessToken, tokenA.accessToken)
        XCTAssertEqual(storedB?.accessToken, tokenB.accessToken)

        XCTAssertTrue(server.calls(to: .revocation).isEmpty, "Running the RAR login must not revoke Token A")
        XCTAssertFalse(server.isRevoked(tokenA.accessToken))
        XCTAssertFalse(server.isRevoked(tokenB.accessToken))
        XCTAssertEqual(server.calls(to: .token).count, 2, "One code exchange per login; both tokens then serve from storage")
    }

    private func assertSelectiveRevokeLeavesPrimaryUntouched(primary: PrimaryLogin) async throws {
        let setup = try await signInThenRar(primary: primary)
        let tokenA = try await setup.primaryUser.token().get()
        let tokenB = try await setup.rarUser.token().get()

        await setup.rarUser.revoke()

        let revocations = server.calls(to: .revocation)
        XCTAssertEqual(revocations.count, 1)
        XCTAssertEqual(revocations.first?.fields["token"], tokenB.refreshToken)
        XCTAssertEqual(revocations.first?.fields["client_id"], setup.rarClientId)
        XCTAssertTrue(server.isRevoked(tokenB.accessToken))
        XCTAssertFalse(server.isRevoked(tokenA.accessToken))

        let storedRar = try await setup.rarStorage.get()
        XCTAssertNil(storedRar, "Token B is removed from its own storage")
        let storedPrimary = try await setup.primaryStorage.get()
        XCTAssertEqual(storedPrimary?.accessToken, tokenA.accessToken, "Token A stays in storage")

        let stillA = try await setup.primaryUser.token().get()
        XCTAssertEqual(stillA.accessToken, tokenA.accessToken, "Token A is still usable")
        XCTAssertEqual(server.calls(to: .token).count, 2, "Token A was served from storage, not re-minted")
    }

    private func assertLogoutTakesOneCallPerWorkflow(primary: PrimaryLogin) async throws {
        let setup = try await signInThenRar(primary: primary)
        let tokenA = try await setup.primaryUser.token().get()
        let tokenB = try await setup.rarUser.token().get()

        // Logging out of the RAR workflow does not reach Token A: nothing links the two.
        await setup.rarUser.logout()
        let primaryAfterRarLogout = try await setup.primaryStorage.get()
        XCTAssertEqual(primaryAfterRarLogout?.accessToken, tokenA.accessToken)
        XCTAssertFalse(server.isRevoked(tokenA.accessToken))
        XCTAssertTrue(server.isRevoked(tokenB.accessToken))
        let rarAfterLogout = try await setup.rarStorage.get()
        XCTAssertNil(rarAfterLogout)
        XCTAssertEqual(server.calls(to: .endSession).first?.fields["id_token_hint"], tokenB.idToken)

        // The second call logs out the original workflow, revoking Token A.
        await setup.primaryUser.logout()
        let primaryAfterLogout = try await setup.primaryStorage.get()
        XCTAssertNil(primaryAfterLogout)
        XCTAssertTrue(server.isRevoked(tokenA.accessToken))

        let revocations = server.calls(to: .revocation)
        XCTAssertEqual(revocations.map { $0.fields["token"] }, [tokenB.refreshToken, tokenA.refreshToken])
        XCTAssertEqual(revocations.map { $0.fields["client_id"] }, [setup.rarClientId, setup.primaryClientId])

        // A native login's sign-off is owned by its own flow (e.g. Journey), so only the browser
        // workflows call the end-session endpoint.
        let expectedEndSessionCalls = primary == .browser ? 2 : 1
        XCTAssertEqual(server.calls(to: .endSession).count, expectedEndSessionCalls)
    }

    // MARK: - Setup helpers

    private enum PrimaryLogin {
        case native
        case browser
    }

    /// The two signed-in workflows: the original login (Token A) and the RAR login (Token B).
    private struct TwoTokenSetup {
        let primaryUser: User
        let primaryStorage: MockStorage<Token>
        let primaryClientId: String
        let rarWorkflow: OidcWebClient
        let rarUser: User
        let rarStorage: MockStorage<Token>
        let rarClientId: String
    }

    /// Signs in with the original login (Token A), then runs the RAR login on its own workflow
    /// and storage (Token B).
    private func signInThenRar(
        primary: PrimaryLogin,
        primaryClientId: String = "iosClient",
        rarClientId: String = "rarClient"
    ) async throws -> TwoTokenSetup {
        let primaryStorage = MockStorage<Token>()
        let primaryUser: User
        switch primary {
        case .native:
            let user = makeNativeUser(clientId: primaryClientId, storage: primaryStorage)
            _ = try await user.token().get()
            primaryUser = user
        case .browser:
            let workflow = makeWebClient(clientId: primaryClientId, storage: primaryStorage)
            primaryUser = try await workflow.authorize().get()
        }

        let rarStorage = MockStorage<Token>()
        let rarWorkflow = makeWebClient(clientId: rarClientId, storage: rarStorage)
        let details = [Self.payment()]
        let rarUser = try await rarWorkflow.authorize { options in
            options.authorizationDetails = details
        }.get()

        return TwoTokenSetup(
            primaryUser: primaryUser,
            primaryStorage: primaryStorage,
            primaryClientId: primaryClientId,
            rarWorkflow: rarWorkflow,
            rarUser: rarUser,
            rarStorage: rarStorage,
            rarClientId: rarClientId
        )
    }

    private func makeWebClient(clientId: String, storage: MockStorage<Token>) -> OidcWebClient {
        OidcWebClient.createOidcWebClient { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.httpClient = MockURLProtocol.makeClient()
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = clientId
                oidcValue.scopes = Set(["openid"])
                oidcValue.redirectUri = "myapp://oauth2redirect"
                oidcValue.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
                oidcValue.storage = storage
            }
        }
    }

    /// A stand-in for a native (Journey / DaVinci style) login: no browser, the agent hands the
    /// client an authorization code directly.
    private func makeNativeUser(clientId: String, storage: MockStorage<Token>) -> OidcUser {
        let config = OidcClientConfig()
        config.clientId = clientId
        config.scopes = Set(["openid"])
        config.redirectUri = "myapp://oauth2redirect"
        config.discoveryEndpoint = MockAPIEndpoint.discovery.url.absoluteString
        config.httpClient = MockURLProtocol.makeClient()
        config.storage = storage
        config.updateAgent(NativeLoginAgent(server: server))
        return OidcUser(config: config)
    }

    private static func payment(amount: String = "123.50") -> AuthorizationDetail {
        AuthorizationDetail(
            type: "payment_initiation",
            actions: ["initiate"],
            additionalFields: [
                "instructedAmount": .object(["currency": .string("EUR"), "amount": .string(amount)])
            ]
        )
    }
}

// MARK: - Test doubles

/// A recorded request to the fake authorization server: the path and the merged query and
/// form fields.
private struct RecordedCall {
    let path: String
    let fields: [String: String]
}

/// A fake authorization server for the discovery, token, revocation and end-session endpoints.
///
/// Tokens are minted per client and remembered, so revocation can behave like a real server:
/// revoking a token under the client it was issued to invalidates its grant; revoking it under a
/// different client is refused with `invalid_client` and leaves it valid (RFC 7009 §2.1).
private final class FakeAuthorizationServer: @unchecked Sendable {
    private let lock = NSLock()
    private var counter = 0
    private var recorded: [RecordedCall] = []
    private var codeOwner: [String: String] = [:]
    private var codeAuthorizationDetails: [String: String] = [:]
    private var tokenOwner: [String: String] = [:]
    private var grantTokens: [String: [String]] = [:]
    private var revoked: Set<String> = []

    /// Called by the fake browser / native agent when the user completes authorization.
    func issueCode(clientId: String, authorizationDetails: String?) -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        let code = "code-\(clientId)-\(counter)"
        codeOwner[code] = clientId
        if let authorizationDetails {
            codeAuthorizationDetails[code] = authorizationDetails
        }
        return code
    }

    func calls(to endpoint: MockAPIEndpoint) -> [RecordedCall] {
        lock.lock()
        defer { lock.unlock() }
        return recorded.filter { $0.path == endpoint.url.path }
    }

    func isRevoked(_ token: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return revoked.contains(token)
    }

    func handle(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        var fields = Self.formFields(from: Self.bodyData(from: request))
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            fields[item.name] = item.value ?? ""
        }
        lock.lock()
        recorded.append(RecordedCall(path: url.path, fields: fields))
        lock.unlock()

        switch url.path {
        case MockAPIEndpoint.discovery.url.path:
            return Self.respond(url: url, status: 200, body: MockResponse.openIdConfiguration)
        case MockAPIEndpoint.token.url.path:
            return try tokenResponse(url: url, fields: fields)
        case MockAPIEndpoint.revocation.url.path:
            return revocationResponse(url: url, fields: fields)
        case MockAPIEndpoint.endSession.url.path:
            return Self.respond(url: url, status: 200, body: Data("{}".utf8))
        default:
            return Self.respond(url: url, status: 404, body: Data("{}".utf8))
        }
    }

    private func tokenResponse(url: URL, fields: [String: String]) throws -> (HTTPURLResponse, Data) {
        lock.lock()
        defer { lock.unlock() }
        guard fields["grant_type"] == "authorization_code",
              let code = fields["code"],
              let owner = codeOwner.removeValue(forKey: code),
              owner == fields["client_id"] else {
            return Self.respond(url: url, status: 400, body: Data(#"{"error":"invalid_grant"}"#.utf8))
        }
        counter += 1
        let access = "AT-\(owner)-\(counter)"
        let refresh = "RT-\(owner)-\(counter)"
        for token in [access, refresh] {
            tokenOwner[token] = owner
            grantTokens[token] = [access, refresh]
        }
        var body: [String: Any] = [
            "access_token": access,
            "token_type": "Bearer",
            "scope": "openid",
            "refresh_token": refresh,
            "expires_in": 3600,
            "id_token": "ID-\(owner)-\(counter)"
        ]
        if let details = codeAuthorizationDetails.removeValue(forKey: code) {
            body["authorization_details"] = try JSONSerialization.jsonObject(with: Data(details.utf8))
        }
        return Self.respond(url: url, status: 200, body: try JSONSerialization.data(withJSONObject: body))
    }

    private func revocationResponse(url: URL, fields: [String: String]) -> (HTTPURLResponse, Data) {
        lock.lock()
        defer { lock.unlock() }
        guard let token = fields["token"], let owner = tokenOwner[token] else {
            // RFC 7009 §2.2: an unknown token is not an error.
            return Self.respond(url: url, status: 200, body: Data("{}".utf8))
        }
        guard owner == fields["client_id"] else {
            return Self.respond(url: url, status: 400, body: Data(#"{"error":"invalid_client"}"#.utf8))
        }
        revoked.formUnion(grantTokens[token] ?? [token])
        return Self.respond(url: url, status: 200, body: Data("{}".utf8))
    }

    private static func respond(url: URL, status: Int, body: Data) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: MockResponse.headers)!, body)
    }

    /// `httpBody` is nil for requests that went through `URLSession` + `URLProtocol`; the data
    /// arrives on `httpBodyStream`.
    private static func bodyData(from request: URLRequest) -> Data {
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

    private static func formFields(from data: Data) -> [String: String] {
        var fields: [String: String] = [:]
        let text = String(decoding: data, as: UTF8.self)
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = parts.first?.removingPercentEncoding else { continue }
            fields[name] = parts.count > 1 ? (parts[1].removingPercentEncoding ?? "") : ""
        }
        return fields
    }
}

/// A browser double that completes the authorize redirect the way a user who signs in and
/// consents would: it reads the authorize URL, has the fake server issue a code for that client
/// (remembering any `authorization_details`), and returns the callback carrying the code and
/// the `state` that was sent.
@MainActor
private final class FakeBrowser: BrowserLauncherProtocol, @unchecked Sendable {
    var isInProgress: Bool = false
    private let server: FakeAuthorizationServer

    init(server: FakeAuthorizationServer) {
        self.server = server
    }

    func launch(
        url: URL,
        customParams: [String: String]?,
        browserType: BrowserType,
        browserMode: BrowserMode,
        callbackURLScheme: String,
        logger: PingLogger.Logger
    ) async throws -> URL {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first(where: { $0.name == name })?.value
        }
        let code = server.issueCode(clientId: value("client_id") ?? "unknown-client",
                                    authorizationDetails: value("authorization_details"))
        var callback = URLComponents(string: value("redirect_uri") ?? "myapp://oauth2redirect")!
        var queryItems = [URLQueryItem(name: "code", value: code)]
        if let state = value("state") {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        callback.queryItems = queryItems
        return callback.url!
    }

    func reset() {}
    func handleAppActivation() {}
}

/// Stands in for a native login (Journey or DaVinci): instead of a browser, the agent asks the
/// fake server for a code and hands it to the client, which exchanges it like any other login.
private final class NativeLoginAgent: Agent, @unchecked Sendable {
    typealias T = Void
    private let server: FakeAuthorizationServer

    init(server: FakeAuthorizationServer) {
        self.server = server
    }

    func config() -> () -> Void {
        return {}
    }

    func endSession(oidcConfig: OidcConfig<Void>, idToken: String) async throws -> Bool {
        return true
    }

    func authorize(oidcConfig: OidcConfig<Void>) async throws -> AuthCode {
        let code = server.issueCode(clientId: oidcConfig.oidcClientConfig.clientId, authorizationDetails: nil)
        return AuthCode(code: code, codeVerifier: nil)
    }
}
