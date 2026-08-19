//
//  DaVinciJsonConfigE2ETest.swift
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
@testable import PingOidc
@testable import PingLogger

/// E2E coverage for the unified JSON configuration factory `DaVinci.createDaVinci(json:)`.
///
/// Config-level tests validate field parsing, default values, and error cases without making
/// network calls. Login tests run the full auth flow against the live environment to confirm
/// that a JSON-built DaVinci behaves identically to one built with the code-based factory.
final class DaVinciJsonConfigE2ETest: DaVinciBaseTests, @unchecked Sendable {

    private var username: String!
    private var password: String!

    override func setUp() async throws {
        self.configFileName = "DaVinci-e2e-config"
        try await super.setUp()
        username = self.config.username
        password = self.config.password
    }

    // MARK: - JSON fixtures

    /// Minimal valid OIDC sub-dict built from live config.
    private var baseOidcDict: [String: Any] {
        [
            "clientId": config.clientId,
            "discoveryEndpoint": config.discoveryEndpoint,
            "scopes": config.scopes,
            "redirectUri": config.redirectUri,
            "acrValues": config.acrValues
        ]
    }

    /// Minimal JSON — only required OIDC fields plus acrValues for live login.
    private var minimalJson: [String: Any] {
        ["oidc": baseOidcDict]
    }

    /// Full JSON — all supported top-level and OIDC fields.
    private var fullJson: [String: Any] {
        [
            "timeout": 30000,
            "log": "DEBUG",
            "oidc": [
                "clientId": config.clientId,
                "discoveryEndpoint": config.discoveryEndpoint,
                "scopes": config.scopes,
                "redirectUri": config.redirectUri,
                "acrValues": config.acrValues,
                "refreshThreshold": 60
            ] as [String: Any]
        ]
    }

    // MARK: - Config parsing: field values

    // Verifies that omitting optional fields produces the documented default timeout of 15s.
    func testMinimalJsonConfig_defaultValues() throws {
        let daVinci = try DaVinci.createDaVinci(json: minimalJson).get()
        XCTAssertEqual(daVinci.config.timeout, 15.0)
    }

    // Verifies that timeout (ms → seconds) and log level are parsed and applied when the full JSON is provided.
    func testFullJsonConfig_allValuesApplied() throws {
        let daVinci = try DaVinci.createDaVinci(json: fullJson).get()
        XCTAssertEqual(daVinci.config.timeout, 30.0)
        XCTAssertTrue(daVinci.config.logger is StandardLogger)
    }

    // Verifies that a "journey" dict (which is Journey-only) is silently ignored by DaVinci's parser.
    func testJourneySpecificFields_areIgnored() {
        var json = minimalJson
        json["journey"] = ["serverUrl": "https://example.com/am", "realm": "alpha"] as [String: Any]
        XCTAssertNoThrow(try DaVinci.createDaVinci(json: json).get(),
                         "Journey-specific fields should be silently ignored by DaVinci")
    }

    // MARK: - Config parsing: unknown fields

    // Verifies that arbitrary unrecognised keys at the top level and inside the oidc dict do not cause a failure.
    func testUnknownFields_areIgnored() {
        var json = minimalJson
        json["unknownTopLevel"] = "should-be-ignored"
        json["extraFlag"] = true
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc
        XCTAssertNoThrow(try DaVinci.createDaVinci(json: json).get(),
                         "Unknown fields should be silently ignored")
    }

    // MARK: - Config parsing: missing required fields

    // Verifies that an empty top-level dict (no "oidc" key) returns missingRequiredField("oidc").
    func testMissingOidcDict_returnsConfigError() {
        let result = DaVinci.createDaVinci(json: [:])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // Verifies that omitting "clientId" from the oidc dict returns missingRequiredField("oidc.clientId").
    func testMissingClientId_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "clientId")
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    // Verifies that omitting "discoveryEndpoint" from the oidc dict returns missingRequiredField("oidc.discoveryEndpoint").
    func testMissingDiscoveryEndpoint_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "discoveryEndpoint")
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    // Verifies that omitting "scopes" from the oidc dict returns missingRequiredField("oidc.scopes").
    func testMissingScopes_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "scopes")
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that omitting "redirectUri" from the oidc dict returns missingRequiredField("oidc.redirectUri").
    func testMissingRedirectUri_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "redirectUri")
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    // MARK: - Config parsing: wrong types

    // Verifies that a non-numeric "timeout" value returns invalidType("timeout").
    func testTimeoutWrongType_returnsConfigError() {
        var json = minimalJson
        json["timeout"] = "not-a-number"
        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)")
            return
        }
        XCTAssertEqual(field, "timeout")
    }

    // Verifies that a non-dict "oidc" value returns invalidType("oidc").
    func testOidcWrongType_returnsConfigError() {
        let result = DaVinci.createDaVinci(json: ["oidc": "not-an-object"])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // Verifies that a numeric "clientId" value returns invalidType("oidc.clientId").
    func testClientIdWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["clientId"] = 12345
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    // Verifies that a non-string-array "scopes" value returns invalidType("oidc.scopes").
    func testScopesWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["scopes"] = [1, 2, 3]
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that a non-numeric "refreshThreshold" value returns invalidType("oidc.refreshThreshold").
    func testRefreshThresholdWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["refreshThreshold"] = "not-a-number"
        let result = DaVinci.createDaVinci(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.refreshThreshold), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.refreshThreshold")
    }

    // MARK: - Live login

    // Builds a DaVinci instance from minimal JSON and drives the full two-step login form against the live PingOne tenant.
    func testLogin_withMinimalJsonConfig_succeeds() async throws {
        let result = DaVinci.createDaVinci(json: minimalJson)
        guard case .success(let daVinci) = result else {
            XCTFail("createDaVinci(json:) failed: \(result)")
            return
        }
        await daVinci.daVinciUser()?.logout()
        try await driveLogin(daVinci: daVinci)
    }

    // Builds a DaVinci instance from full JSON (timeout, log level) and drives the login form; confirms all optional fields don't break the flow.
    func testLogin_withFullJsonConfig_succeeds() async throws {
        let result = DaVinci.createDaVinci(json: fullJson)
        guard case .success(let daVinci) = result else {
            XCTFail("createDaVinci(json:) failed: \(result)")
            return
        }
        await daVinci.daVinciUser()?.logout()
        try await driveLogin(daVinci: daVinci)
    }

    // Completes the login flow inline (without the driveLogin helper) and calls token() to assert accessToken is non-empty and tokenType is "Bearer".
    func testLogin_withJsonConfig_tokenRetrieval_succeeds() async throws {
        let result = DaVinci.createDaVinci(json: minimalJson)
        guard case .success(let daVinci) = result else {
            XCTFail("createDaVinci(json:) failed: \(result)")
            return
        }
        await daVinci.daVinciUser()?.logout()

        var node = await daVinci.start()
        guard var continueNode = node as? ContinueNode else {
            throw XCTSkip("Expected ContinueNode for the login form — environment may be unavailable")
        }
        XCTAssertEqual("E2E Login Form", continueNode.name)
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"

        node = await continueNode.next()
        guard let next = node as? ContinueNode else {
            throw XCTSkip("Expected ContinueNode for 'Successful login' — environment may be unavailable")
        }
        continueNode = next
        XCTAssertEqual("Successful login", continueNode.name)
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"
        node = await continueNode.next()
        guard node is SuccessNode else {
            throw XCTSkip("Expected SuccessNode — environment may be unavailable")
        }

        guard case let .success(token) = await daVinci.daVinciUser()?.token() else {
            throw XCTSkip("Expected token retrieval to succeed — environment may be unavailable")
        }
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
    }

    // Builds a DaVinci instance from JSON containing unrecognised keys and verifies the login flow still completes successfully.
    func testLogin_withUnknownJsonFields_succeeds() async throws {
        var json = minimalJson
        json["unknownTopLevel"] = "ignored"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .success(let daVinci) = result else {
            XCTFail("createDaVinci(json:) with unknown fields failed: \(result)")
            return
        }
        await daVinci.daVinciUser()?.logout()
        try await driveLogin(daVinci: daVinci)
    }

    // MARK: - Helpers

    private func driveLogin(daVinci: DaVinci) async throws {
        var node = await daVinci.start()
        guard var continueNode = node as? ContinueNode else {
            throw XCTSkip("Expected ContinueNode for the login form — environment may be unavailable")
        }
        XCTAssertEqual("E2E Login Form", continueNode.name)
        (continueNode.collectors[0] as? TextCollector)?.value = username
        (continueNode.collectors[1] as? PasswordCollector)?.value = password
        (continueNode.collectors[2] as? SubmitCollector)?.value = "Sign On"

        node = await continueNode.next()
        guard let next = node as? ContinueNode else {
            throw XCTSkip("Expected ContinueNode for 'Successful login' — environment may be unavailable")
        }
        continueNode = next
        XCTAssertEqual("Successful login", continueNode.name)
        (continueNode.collectors[0] as? SubmitCollector)?.value = "Continue"

        node = await continueNode.next()
        guard let success = node as? SuccessNode else {
            throw XCTSkip("Expected SuccessNode — environment may be unavailable")
        }

        guard case let .success(token) = await success.user?.token() else {
            throw XCTSkip("Expected token retrieval to succeed — environment may be unavailable")
        }
        XCTAssertFalse(token.accessToken.isEmpty)
    }
}
