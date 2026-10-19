//
//  JourneyBackchannelE2ETest.swift
//  JourneyTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingLogger

/// E2E coverage for AM/AIC transactional backchannel authentication
///
/// There is no federation gateway in this test environment, so each test simulates the
/// gateway's role itself:
///  1. Obtain a gateway access token via the OAuth2 client-credentials grant
///     (`backchannelClientId` / `backchannelClientSecret`, scope `back_channel_authentication`).
///  2. Call AM's `/authenticate/backchannel/initialize` with that token to obtain a `redirectUri`.
///  3. Hand that `redirectUri` to `Journey.start(backchannelUri:)`, exactly as an app would after
///     receiving it from a real gateway.
///
final class JourneyBackchannelE2ETest: JourneyE2EBaseTest, @unchecked Sendable {

    /// The Journey exercised by every test below — must exist on the shared QA tenant with at
    /// least one callback (e.g. username/password) after the transaction bootstrap.
    private let testTree = "back-channel-authentication"

    private lazy var backchannelClientId: String = (config.configJSON?["backchannelClientId"] as? String) ?? ""
    private lazy var backchannelClientSecret: String = (config.configJSON?["backchannelClientSecret"] as? String) ?? ""

    // MARK: - Positive flows (TC-01, TC-02)

    func testHappyPath_returnsSuccessNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()

        let node = await completeBackchannelLogin(from: await defaultJourney.start(backchannelUri: redirectUri))

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after backchannel authentication, got \(type(of: node))")
        let session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected a session to be created")
    }

    // MARK: - Host match is case-insensitive (TC-03)

    func testHostUpperCased_returnsSuccessNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let upperCasedHostUri = redirectUri.withUppercasedHost()

        let node = await completeBackchannelLogin(from: await defaultJourney.start(backchannelUri: upperCasedHostUri))

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after backchannel authentication, got \(type(of: node))")
        let session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected a session to be created")
    }

    // MARK: - Invalid credentials on a backchannel-continued login (TC-22)

    func testInvalidCredentials_returnsErrorNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()

        let firstNode = await defaultJourney.start(backchannelUri: redirectUri)
        let node = await completeBackchannelLogin(from: firstNode, username: "invalidUser", password: "invalidPassword")

        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode for invalid credentials, got \(type(of: node))")
            return
        }
        XCTAssertEqual(errorNode.message, "Login failure")
        let session = await defaultJourney.session()
        XCTAssertNil(session, "Expected no session to be created after failed login")
    }

    // MARK: - Missing authIndexType / authIndexValue (TC-04, TC-05)

    func testMissingAuthIndexType_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uri = redirectUri.withoutQueryParam("authIndexType")

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "Invalid URI or missing authIndexType/authIndexValue")
    }

    func testMissingAuthIndexValue_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uri = redirectUri.withoutQueryParam("authIndexValue")

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "Invalid URI or missing authIndexType/authIndexValue")
    }

    // MARK: - Blank/whitespace-only parameter values (TC-06)

    func testEmptyAuthIndexType_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uri = redirectUri.withQueryParam("authIndexType", value: "")

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "Invalid URI or missing authIndexType/authIndexValue")
    }

    func testWhitespaceOnlyAuthIndexType_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uri = redirectUri.withQueryParam("authIndexType", value: " ")

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "Invalid URI or missing authIndexType/authIndexValue")
    }

    func testWhitespaceOnlyAuthIndexValue_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uri = redirectUri.withQueryParam("authIndexValue", value: "  ")

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "Invalid URI or missing authIndexType/authIndexValue")
    }

    // MARK: - Malformed / unparseable URI string (TC-07)

    func testMalformedUriString_returnsFailureNodeWithoutCrashing() async throws {
        let malformedString = "not a uri at all !!"
        guard let uri = URL(string: malformedString) else {
            return
        }

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "backchannelUri host does not match JourneyConfig.serverUrl")
    }

    // MARK: - Opaque (non-hierarchical) URI (TC-08)

    func testOpaqueUri_returnsFailureNode() async throws {
        let uri = URL(string: "mailto:user@example.com")!

        let node = await defaultJourney.start(backchannelUri: uri)

        assertFailureNode(node, expectedMessage: "backchannelUri host does not match JourneyConfig.serverUrl")
    }

    // MARK: - Host mismatch (security) (TC-09)

    func testHostMismatch_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let maliciousUri = redirectUri.withHost("attacker.example.com")

        let node = await defaultJourney.start(backchannelUri: maliciousUri)

        assertFailureNode(node, expectedMessage: "backchannelUri host does not match JourneyConfig.serverUrl")
    }

    // MARK: - JourneyConfig absent / serverUrl unset (TC-10)

    func testJourneyConfigAbsent_returnsFailureNode() async throws {
        let rawWorkflow = Workflow(config: WorkflowConfig())

        let node = await rawWorkflow.start(backchannelUri: placeholderBackchannelUri)

        assertFailureNode(node, expectedMessage: "JourneyConfig missing")
    }

    func testServerUrlUnset_returnsFailureNode() async throws {
        let journeyWithoutServerUrl = Journey.createJourney { config in
            config.realm = self.realm
            config.cookie = self.cookie
            // serverUrl deliberately left unset
        }

        let node = await journeyWithoutServerUrl.start(backchannelUri: placeholderBackchannelUri)

        assertFailureNode(node, expectedMessage: "backchannelUri host does not match JourneyConfig.serverUrl")
    }

    // MARK: - Realm in the URI is ignored (TC-11)

    func testRealmInUriIgnored_returnsSuccessNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let uriWithWrongRealm = redirectUri.withQueryParam("realm", value: "/bravo")

        let node = await completeBackchannelLogin(from: await defaultJourney.start(backchannelUri: uriWithWrongRealm))

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after backchannel authentication, got \(type(of: node))")
        let session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected a session to be created")
    }

    // MARK: - Option-flag flows (TC-14, TC-15)

    func testForceAuthOption_returnsSuccessNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()

        let firstNode = await defaultJourney.start(backchannelUri: redirectUri) { options in
            options.forceAuth = true
        }
        let node = await completeBackchannelLogin(from: firstNode)

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after backchannel authentication with forceAuth=true, got \(type(of: node))")
        let session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected a session to be created")
    }

    func testNoSessionOption_doesNotPersistSession() async throws {
        let redirectUri = try await initializeBackchannelTransaction()

        let firstNode = await defaultJourney.start(backchannelUri: redirectUri) { options in
            options.noSession = true
        }
        let node = await completeBackchannelLogin(from: firstNode)

        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after backchannel authentication with noSession=true, got \(type(of: node))")
        let session = await defaultJourney.session()
        XCTAssertNil(session, "Expected no session to be persisted when noSession=true")
    }

    // MARK: - AM rejects an unknown transaction (TC-17)

    func testUnknownTransaction_returnsErrorNode() async throws {
        let unknownTransactionUri = URL(string: "\(serverUrl!)/UI/Login?realm=%2F\(realm!)&authIndexType=transaction&authIndexValue=\(UUID().uuidString)")!

        let node = await defaultJourney.start(backchannelUri: unknownTransactionUri)

        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode for unknown transaction, got \(type(of: node))")
            return
        }
        XCTAssertEqual(errorNode.message, "Unable to read transaction.")
    }

    // MARK: - Network error during the authenticate call (TC-19)

    func testNetworkErrorDuringAuthenticate_returnsFailureNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()
        let journeyWithShortTimeout = Journey.createJourney { config in
            config.serverUrl = self.serverUrl
            config.realm = self.realm
            config.cookie = self.cookie
            config.timeout = 0.001
        }

        let node = await journeyWithShortTimeout.start(backchannelUri: redirectUri)

        guard let failureNode = node as? FailureNode else {
            XCTFail("Expected FailureNode but got \(type(of: node))")
            return
        }
        XCTAssertTrue(failureNode.cause.localizedDescription.contains("Request timed out"),
                      "Expected a timeout error but got \(failureNode.cause)")
    }

    // MARK: - Transaction state flows (TC-23, TC-24)

    /// Reusing an already-`COMPLETED` transaction.
    ///
    func testCompletedTransactionReused_returnsErrorNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction()

        let firstResult = await completeBackchannelLogin(from: await defaultJourney.start(backchannelUri: redirectUri))
        XCTAssertTrue(firstResult is SuccessNode, "Expected SuccessNode on first use, got \(type(of: firstResult))")

        if case .failure(let error) = await defaultJourney.journeySignOff() {
            XCTFail("Sign-off failed: \(error)")
        }

        let secondStart = await defaultJourney.start(backchannelUri: redirectUri)
        guard secondStart is ContinueNode else {
            XCTFail("Expected AM to restart the journey with a fresh ContinueNode on reuse, got \(type(of: secondStart))")
            return
        }
        let secondResult = await completeBackchannelLogin(from: secondStart)

        guard let errorNode = secondResult as? ErrorNode else {
            XCTFail("Expected ErrorNode when finalizing an already-completed transaction, got \(type(of: secondResult))")
            return
        }
        XCTAssertEqual(errorNode.message, "Unable to approve transaction")
    }

    /// `allowRetry: false` denies the transaction after the first failure.
    ///
    func testDeniedTransactionRetried_returnsErrorNode() async throws {
        let redirectUri = try await initializeBackchannelTransaction(allowRetry: false)

        let firstResult = await completeBackchannelLogin(
            from: await defaultJourney.start(backchannelUri: redirectUri),
            username: "invalidUser",
            password: "invalidPassword"
        )
        guard let firstError = firstResult as? ErrorNode else {
            XCTFail("Expected ErrorNode on first failed attempt, got \(type(of: firstResult))")
            return
        }
        XCTAssertEqual(firstError.message, "Login failure")

        let secondResult = await completeBackchannelLogin(from: await defaultJourney.start(backchannelUri: redirectUri))

        guard let secondError = secondResult as? ErrorNode else {
            XCTFail("Expected ErrorNode when retrying a denied transaction, got \(type(of: secondResult))")
            return
        }
        XCTAssertEqual(secondError.message, "Unable to approve transaction")
    }

    // MARK: - Helpers

    /// Completes a `ContinueNode`'s username/password callbacks and advances to the next node.
    /// If `node` is not a `ContinueNode` (e.g. it's already a `SuccessNode`/`ErrorNode`/`FailureNode`),
    /// it is returned unchanged.
    @discardableResult
    private func completeBackchannelLogin(from node: Node, username: String? = nil, password: String? = nil) async -> Node {
        guard let continueNode = node as? ContinueNode else { return node }
        // The transaction already carries `data.username` from the gateway's
        // /initialize call, so AM may render only a PasswordCallback (no NameCallback) —
        // scan by type rather than assuming a fixed first/last layout.
        for callback in continueNode.callbacks {
            if let nameCallback = callback as? NameCallback {
                nameCallback.name = username ?? self.username
            } else if let passwordCallback = callback as? PasswordCallback {
                passwordCallback.password = password ?? self.password
            }
        }
        return await continueNode.next()
    }

    /// Asserts `node` is a `FailureNode` and, if `expectedMessage` is provided, that its `cause`
    /// is an `ApiError` whose message *contains* that text.
    ///
    @discardableResult
    private func assertFailureNode(_ node: Node, expectedMessage: String? = nil, file: StaticString = #filePath, line: UInt = #line) -> FailureNode? {
        guard let failureNode = node as? FailureNode else {
            XCTFail("Expected FailureNode but got \(type(of: node))", file: file, line: line)
            return nil
        }
        if let expectedMessage {
            guard let apiError = failureNode.cause as? ApiError, case .error(_, _, let message) = apiError else {
                XCTFail("Expected ApiError cause but got \(failureNode.cause)", file: file, line: line)
                return failureNode
            }
            XCTAssertTrue(message.contains(expectedMessage),
                          "Expected message to contain \"\(expectedMessage)\" but got \"\(message)\"",
                          file: file, line: line)
        }
        return failureNode
    }

    /// A syntactically valid backchannel URI that is never dereferenced — used by test cases
    /// whose validation guard fires before the URI is ever inspected (TC-10).
    private var placeholderBackchannelUri: URL {
        URL(string: "\(serverUrl!)/UI/Login?authIndexType=transaction&authIndexValue=placeholder")!
    }

    // MARK: - Gateway simulation
    //
    // Simulates the federation gateway (manual test plan §2.2): obtains a client-credentials
    // access token, then calls `/authenticate/backchannel/initialize` for `testTree` and
    // `username`, returning the `redirectUri` from the response. Uses `URLSession` directly
    // rather than the SDK's own HTTP stack, since this is standing in for a third-party gateway
    // service entirely outside the SDK.

    private enum BackchannelGatewayError: Error, CustomStringConvertible {
        case requestFailed(String, Int?)
        case missingField(String, String)

        var description: String {
            switch self {
            case .requestFailed(let label, let status):
                return "\(label) call failed: HTTP \(status.map(String.init) ?? "?")"
            case .missingField(let label, let field):
                return "\(label) response missing '\(field)'"
            }
        }
    }

    private func obtainGatewayAccessToken() async throws -> String {
        var request = URLRequest(url: URL(string: "\(serverUrl!)/oauth2/\(realm!)/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "grant_type": "client_credentials",
            "client_id": backchannelClientId,
            "client_secret": backchannelClientSecret,
            "scope": "back_channel_authentication"
        ]
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BackchannelGatewayError.requestFailed("access_token", (response as? HTTPURLResponse)?.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw BackchannelGatewayError.missingField("access_token", "access_token")
        }
        return accessToken
    }

    /// [allowRetry] is forwarded to AM as-is (default `true`, matching AM's own default) — pass
    /// `false` to test the "first failure denies the transaction" behavior (TC-24).
    private func initializeBackchannelTransaction(allowRetry: Bool = true) async throws -> URL {
        let accessToken = try await obtainGatewayAccessToken()

        var request = URLRequest(url: URL(string: "\(serverUrl!)/json/realms/root/realms/\(realm!)/authenticate/backchannel/initialize")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("resource=1, protocol=2.0", forHTTPHeaderField: "Accept-API-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "type": "service",
            "value": testTree,
            "data": ["username": username as Any],
            "allowRetry": allowRetry
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BackchannelGatewayError.requestFailed("backchannel/initialize", (response as? HTTPURLResponse)?.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let redirectUriString = json["redirectUri"] as? String,
              let redirectUri = URL(string: redirectUriString) else {
            throw BackchannelGatewayError.missingField("backchannel/initialize", "redirectUri")
        }
        return redirectUri
    }
}

// MARK: - URL query manipulation

/// Helpers for constructing negative-test-case variants of a real `redirectUri`, mirroring the
/// Android suite's `String` extension functions of the same names.
private extension URL {
    func withoutQueryParam(_ name: String) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = components.queryItems?.filter { $0.name != name }
        return components.url ?? self
    }

    func withQueryParam(_ name: String, value: String) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var items = components.queryItems ?? []
        if let index = items.firstIndex(where: { $0.name == name }) {
            items[index] = URLQueryItem(name: name, value: value)
        } else {
            items.append(URLQueryItem(name: name, value: value))
        }
        components.queryItems = items
        return components.url ?? self
    }

    func withHost(_ newHost: String) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.host = newHost
        return components.url ?? self
    }

    func withUppercasedHost() -> URL {
        guard let host = self.host else { return self }
        return withHost(host.uppercased())
    }
}
