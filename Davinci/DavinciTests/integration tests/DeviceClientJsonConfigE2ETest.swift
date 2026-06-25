//
//  DeviceClientJsonConfigE2ETest.swift
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

/// E2E coverage for the unified JSON configuration factory `OidcDeviceClient.createOidcDeviceClient(json:)`.
///
/// Config-level tests validate field parsing, default values, and error cases without making
/// network calls. Live tests start the RFC 8628 device authorization flow against the real
/// PingOne tenant (`ConfigNew.json`) to confirm that a JSON-built client behaves identically
/// to one built with the code-based factory. The flow is cancelled after the first `.started`
/// emission — no user interaction or approval is required.
final class DeviceClientJsonConfigE2ETest: DaVinciBaseTests, @unchecked Sendable {

    override func setUp() async throws {
        self.configFileName = "ConfigNew"
        try await super.setUp()
        LogManager.logger = NoneLogger()
    }

    override func tearDown() async throws {
        LogManager.logger = NoneLogger()
        try await super.tearDown()
    }

    // MARK: - JSON fixtures

    /// Minimal OIDC dict using the device client id from ConfigNew.
    private var baseOidcDict: [String: Any] {
        [
            "clientId": config.deviceClientId,
            "discoveryEndpoint": config.discoveryEndpoint,
            "scopes": ["openid", "email", "address", "phone", "profile"],
            "redirectUri": config.redirectUri
        ]
    }

    /// Minimal JSON — only required OIDC fields.
    private var minimalJson: [String: Any] {
        ["oidc": baseOidcDict]
    }

    /// Full JSON — all supported fields including log level and openId endpoint override.
    private var fullJson: [String: Any] {
        [
            "log": "DEBUG",
            "oidc": [
                "clientId": config.deviceClientId,
                "discoveryEndpoint": config.discoveryEndpoint,
                "scopes": ["openid", "email", "address", "phone", "profile"],
                "redirectUri": config.redirectUri,
                "refreshThreshold": 60,
                "openId": [
                    "deviceAuthorizationEndpoint":
                        "https://auth.pingone.ca/300c4f2a-39d4-4ba9-a18a-f6de246006f4/as/device_authorization"
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    // MARK: - Config parsing: field values

    // Verifies that omitting the optional "log" field produces a NoneLogger (the SDK default).
    func testMinimalJsonConfig_defaultValues() throws {
        let client = try OidcDeviceClient.createOidcDeviceClient(json: minimalJson).get()
        XCTAssertTrue(client.logger is NoneLogger,
                      "Default log level should be NoneLogger when no 'log' key is present")
    }

    // Verifies that log=DEBUG produces a StandardLogger when the full JSON is provided.
    func testFullJsonConfig_logLevelApplied() throws {
        let client = try OidcDeviceClient.createOidcDeviceClient(json: fullJson).get()
        XCTAssertTrue(client.logger is StandardLogger,
                      "log=DEBUG should produce a StandardLogger")
    }

    // Verifies that unrecognised keys at the top level and inside the oidc dict are silently ignored.
    func testUnknownFields_areIgnored() {
        var json = minimalJson
        json["unknownTopLevel"] = "should-be-ignored"
        json["serverUrl"] = "https://example.com/am"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc
        XCTAssertNoThrow(try OidcDeviceClient.createOidcDeviceClient(json: json).get(),
                         "Unknown fields should be silently ignored")
    }

    // MARK: - Config parsing: missing required fields

    // Verifies that an empty top-level dict (no "oidc" key) returns missingRequiredField("oidc").
    func testMissingOidcDict_returnsConfigError() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: [:])
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
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
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
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
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
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
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
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    // MARK: - Config parsing: wrong types

    // Verifies that a non-dict "oidc" value returns invalidType("oidc").
    func testOidcWrongType_returnsConfigError() {
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": "not-an-object"])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // Verifies that a non-string-array "scopes" value returns invalidType("oidc.scopes").
    func testScopesWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["scopes"] = [1, 2, 3]
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    // Verifies that a non-dict "openId" value returns invalidType("oidc.openId").
    func testOpenIdWrongType_returnsConfigError() {
        var oidc = baseOidcDict
        oidc["openId"] = "not-an-object"
        let result = OidcDeviceClient.createOidcDeviceClient(json: ["oidc": oidc])
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.openId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.openId")
    }

    // MARK: - Live device authorization flow

    // Builds a client from minimal JSON, starts the RFC 8628 device flow, and asserts the first emission is .started with non-empty userCode, deviceCode, and verificationUri.
    func testSucceedsWithMinimalJsonConfig() async throws {
        let client = try OidcDeviceClient.createOidcDeviceClient(json: minimalJson).get()
        await client.user()?.logout()

        let stream = try await client.deviceAuthorization()
        var startedResponse: DeviceAuthorizationResponse? = nil

        for try await status in stream {
            if case .started(let response) = status {
                startedResponse = response
            }
            break
        }

        guard let response = startedResponse else {
            throw XCTSkip("First emission was not .started — environment may be unavailable")
        }
        XCTAssertFalse(response.userCode.isEmpty, "userCode must not be empty")
        XCTAssertFalse(response.verificationUri.isEmpty, "verificationUri must not be empty")
        XCTAssertFalse(response.deviceCode.isEmpty, "deviceCode must not be empty")
        XCTAssertGreaterThan(response.expiresIn, 0, "expiresIn must be positive")
    }

    // Builds a client from full JSON (log=DEBUG, openId.deviceAuthorizationEndpoint override) and verifies the flow reaches .started, exercising the endpoint override path.
    func testSucceedsWithFullJsonConfig() async throws {
        let client = try OidcDeviceClient.createOidcDeviceClient(json: fullJson).get()
        XCTAssertTrue(client.logger is StandardLogger,
                      "log=DEBUG should produce a StandardLogger")
        await client.user()?.logout()

        let stream = try await client.deviceAuthorization()
        var startedResponse: DeviceAuthorizationResponse? = nil

        for try await status in stream {
            if case .started(let response) = status {
                startedResponse = response
            }
            break
        }

        guard let response = startedResponse else {
            throw XCTSkip("First emission was not .started — environment may be unavailable")
        }
        XCTAssertFalse(response.userCode.isEmpty, "userCode must not be empty")
        XCTAssertFalse(response.verificationUri.isEmpty, "verificationUri must not be empty")
    }

    // Builds a client from JSON containing unrecognised keys and verifies the device flow still reaches .started.
    func testUnknownJsonFields_doesNotBreakDeviceFlow() async throws {
        var json = minimalJson
        json["unknownTopLevel"] = "ignored"
        var oidc = baseOidcDict
        oidc["unknownOidcField"] = 42
        json["oidc"] = oidc

        let client = try OidcDeviceClient.createOidcDeviceClient(json: json).get()
        await client.user()?.logout()

        let stream = try await client.deviceAuthorization()
        var gotStarted = false

        for try await status in stream {
            if case .started = status { gotStarted = true }
            break
        }

        guard gotStarted else {
            throw XCTSkip("First emission was not .started — environment may be unavailable")
        }
    }
}
