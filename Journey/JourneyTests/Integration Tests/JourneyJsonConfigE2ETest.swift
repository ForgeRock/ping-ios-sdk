//
//  JourneyJsonConfigE2ETest.swift
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
@testable import PingOidc
@testable import PingLogger

/// E2E coverage for the unified JSON configuration factory `Journey.createJourney(json:)`.
///
/// Config-level tests validate field parsing, default values, and error cases without making
/// network calls. Login tests run the full auth flow against the live environment to confirm
/// that a JSON-built Journey behaves identically to one built with the code-based factory.
final class JourneyJsonConfigE2ETest: JourneyE2EBaseTest, @unchecked Sendable {

    // MARK: - JSON fixtures

    /// Minimal JSON built from live config — only required fields.
    private var minimalJson: [String: Any] {
        [
            "journey": [
                "serverUrl": serverUrl!
            ] as [String: Any],
            "oidc": [
                "clientId": clientId!,
                "discoveryEndpoint": discoveryEndpoint!,
                "scopes": scopes!,
                "redirectUri": redirectUri!
            ] as [String: Any]
        ]
    }

    /// Minimal JSON with just enough to authenticate against the live environment.
    /// Includes `realm` and `cookieName` because this environment's "Login" tree lives
    /// in the `alpha` realm — using the "root" default would cause a 400.
    private var loginReadyJson: [String: Any] {
        [
            "journey": [
                "serverUrl": serverUrl!,
                "realm": realm!,
                "cookieName": cookie!
            ] as [String: Any],
            "oidc": [
                "clientId": clientId!,
                "discoveryEndpoint": discoveryEndpoint!,
                "scopes": scopes!,
                "redirectUri": redirectUri!
            ] as [String: Any]
        ]
    }

    /// Full JSON built from live config — all supported fields.
    private var fullJson: [String: Any] {
        [
            "timeout": 30000,
            "log": "DEBUG",
            "journey": [
                "serverUrl": serverUrl!,
                "realm": realm!,
                "cookieName": cookie!
            ] as [String: Any],
            "oidc": [
                "clientId": clientId!,
                "discoveryEndpoint": discoveryEndpoint!,
                "scopes": scopes!,
                "redirectUri": redirectUri!,
                "refreshThreshold": 60
            ] as [String: Any]
        ]
    }

    /// Minimal valid oidc sub-dict built from live config.
    private var baseOidcDict: [String: Any] {
        [
            "clientId": clientId!,
            "discoveryEndpoint": discoveryEndpoint!,
            "scopes": scopes!,
            "redirectUri": redirectUri!
        ]
    }

    // MARK: - Config parsing: field values

    // Verifies that omitting optional fields produces documented defaults: realm="root", cookie="iPlanetDirectoryPro", timeout=15s.
    func testMinimalJsonConfig_defaultJourneyValues() throws {
        let result = Journey.createJourney(json: minimalJson)
        let journey = try result.get()
        let journeyConfig = try XCTUnwrap(journey.config as? JourneyConfig)

        XCTAssertEqual(journeyConfig.serverUrl, serverUrl)
        XCTAssertEqual(journeyConfig.realm, "root")
        XCTAssertEqual(journeyConfig.cookie, "iPlanetDirectoryPro")
        XCTAssertEqual(journey.config.timeout, 15.0)
    }

    // Verifies that all supported fields (timeout in ms, log level, realm, cookieName) are parsed and applied correctly.
    func testFullJsonConfig_allValuesApplied() throws {
        let result = Journey.createJourney(json: fullJson)
        let journey = try result.get()
        let journeyConfig = try XCTUnwrap(journey.config as? JourneyConfig)

        XCTAssertEqual(journeyConfig.serverUrl, serverUrl)
        XCTAssertEqual(journeyConfig.realm, realm)
        XCTAssertEqual(journeyConfig.cookie, cookie)
        XCTAssertEqual(journey.config.timeout, 30.0)
        XCTAssertTrue(journey.config.logger is StandardLogger)
    }

    // Verifies that an explicit cookieName value overrides the default "iPlanetDirectoryPro".
    func testCustomCookieName_isApplied() throws {
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!, "cookieName": "MyTestCookie"] as [String: Any],
            "oidc": baseOidcDict
        ]
        let journey = try Journey.createJourney(json: json).get()
        let journeyConfig = try XCTUnwrap(journey.config as? JourneyConfig)
        XCTAssertEqual(journeyConfig.cookie, "MyTestCookie")
    }

    // MARK: - Config parsing: unknown fields

    // Verifies that unrecognised keys at the top level, inside the journey dict, and inside the oidc dict do not cause a failure.
    func testUnknownFields_areIgnored() {
        var json = minimalJson
        json["unknownTopLevel"] = "should-be-ignored"
        json["extraFlag"] = true
        json["journey"] = [
            "serverUrl": serverUrl!,
            "unknownJourneyField": "also-ignored"
        ] as [String: Any]
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        XCTAssertNoThrow(try result.get(), "Unknown fields should be silently ignored")
    }

    // MARK: - Config parsing: missing required fields

    // Verifies that an empty top-level dict (no "journey" key) returns missingRequiredField("journey").
    func testMissingJourneyDict_returnsConfigError() {
        let result = Journey.createJourney(json: [:])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(journey), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey")
    }

    // Verifies that an empty journey dict (no "serverUrl" key) returns missingRequiredField("journey.serverUrl").
    func testMissingServerUrl_returnsConfigError() {
        let result = Journey.createJourney(json: ["journey": [String: Any]()])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(journey.serverUrl), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.serverUrl")
    }

    // Verifies that omitting "clientId" from the oidc dict returns missingRequiredField("oidc.clientId").
    func testMissingOidcClientId_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "clientId")
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    // Verifies that omitting "discoveryEndpoint" from the oidc dict returns missingRequiredField("oidc.discoveryEndpoint").
    func testMissingOidcDiscoveryEndpoint_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "discoveryEndpoint")
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    // Verifies that omitting "scopes" from the oidc dict returns missingRequiredField("oidc.scopes").
    func testMissingOidcScopes_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "scopes")
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that omitting "redirectUri" from the oidc dict returns missingRequiredField("oidc.redirectUri").
    func testMissingOidcRedirectUri_returnsConfigError() {
        var oidc = baseOidcDict
        oidc.removeValue(forKey: "redirectUri")
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
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
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)")
            return
        }
        XCTAssertEqual(field, "timeout")
    }

    // Verifies that a numeric "serverUrl" value returns invalidType("journey.serverUrl").
    func testServerUrlWrongType_returnsConfigError() {
        let json: [String: Any] = [
            "journey": ["serverUrl": 12345] as [String: Any]
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.serverUrl), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.serverUrl")
    }

    // Verifies that a numeric "realm" value returns invalidType("journey.realm").
    func testRealmWrongType_returnsConfigError() {
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!, "realm": 999] as [String: Any]
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.realm), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.realm")
    }

    // Verifies that a numeric "cookieName" value returns invalidType("journey.cookieName").
    func testCookieNameWrongType_returnsConfigError() {
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!, "cookieName": 42] as [String: Any],
            "oidc": baseOidcDict
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.cookieName), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.cookieName")
    }

    // Verifies that a non-string-array "scopes" value returns invalidType("oidc.scopes").
    func testScopesWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["scopes"] = [1, 2, 3]
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
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
        let json: [String: Any] = [
            "journey": ["serverUrl": serverUrl!] as [String: Any],
            "oidc": oidc
        ]
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.refreshThreshold), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.refreshThreshold")
    }

    // Verifies that a non-dict "oidc" value returns invalidType("oidc").
    func testOidcWrongType_returnsConfigError() {
        var json = minimalJson
        json["oidc"] = "not-an-object"
        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // MARK: - Live login

    // Builds a Journey from minimal JSON (realm + cookieName to match the alpha environment) and completes the Login tree; asserts SuccessNode and a non-nil session.
    func testLogin_withMinimalJsonConfig_succeeds() async throws {
        let result = Journey.createJourney(json: loginReadyJson)
        guard case .success(let journey) = result else {
            XCTFail("createJourney(json:) failed: \(result)")
            return
        }
        await journey.journeyUser()?.logout()

        let node = try await handleLoginCallbacks(journey: journey, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")

        let session = await journey.session()
        XCTAssertNotNil(session)
        XCTAssertNotNil(session?.value)
    }

    // Builds a Journey from full JSON (all fields) and completes the Login tree; verifies a JSON-configured client works end-to-end.
    func testLogin_withFullJsonConfig_succeeds() async throws {
        let result = Journey.createJourney(json: fullJson)
        guard case .success(let journey) = result else {
            XCTFail("createJourney(json:) failed: \(result)")
            return
        }
        await journey.journeyUser()?.logout()

        let node = try await handleLoginCallbacks(journey: journey, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")

        let session = await journey.session()
        XCTAssertNotNil(session)
    }

    // Completes a full login flow and then calls token() to assert the resulting access token is non-empty and of type "Bearer".
    func testLogin_withJsonConfig_tokenRetrieval_succeeds() async throws {
        let result = Journey.createJourney(json: loginReadyJson)
        guard case .success(let journey) = result else {
            XCTFail("createJourney(json:) failed: \(result)")
            return
        }
        await journey.journeyUser()?.logout()

        let node = try await handleLoginCallbacks(journey: journey, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")

        guard case let .success(token) = await journey.journeyUser()?.token() else {
            XCTFail("Expected token retrieval to succeed")
            return
        }
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertEqual(token.tokenType, "Bearer")
    }

    // Builds a Journey from JSON containing unrecognised keys and verifies the login flow still completes successfully.
    func testLogin_withUnknownJsonFields_succeeds() async throws {
        var json = loginReadyJson
        json["unknownTopLevel"] = "ignored"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("createJourney(json:) with unknown fields failed: \(result)")
            return
        }
        await journey.journeyUser()?.logout()

        let node = try await handleLoginCallbacks(journey: journey, treeName: "Login")
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode, got \(type(of: node))")
    }
}
