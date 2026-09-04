//
//  OidcWebClientJsonConfigTests.swift
//  OidcTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
@testable import PingLogger

final class OidcWebClientJsonConfigTests: XCTestCase, @unchecked Sendable {

    private var minimalJson: [String: Any] {
        [
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid"],
                "redirectUri": "myapp://callback"
            ] as [String: Any]
        ]
    }

    private var fullJson: [String: Any] {
        [
            "timeout": 20000,
            "log": "DEBUG",
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid", "profile", "email"],
                "redirectUri": "myapp://callback",
                "signOutRedirectUri": "myapp://logout",
                "refreshThreshold": 30,
                "acrValues": "Level3",
                "additionalParameters": ["custom": "value"]
            ] as [String: Any]
        ]
    }

    /// A fully-specified `openId` sub-object with no `discoveryEndpoint` — exercises the
    /// full-replacement skip-discovery branch of `OidcClientConfig.apply(json:)`.
    private var openIdOnlyJson: [String: Any] {
        [
            "oidc": [
                "clientId": "my-client",
                "scopes": ["openid"],
                "redirectUri": "myapp://callback",
                "openId": [
                    "authorizationEndpoint": "https://example.com/authorize",
                    "tokenEndpoint": "https://example.com/token",
                    "userinfoEndpoint": "https://example.com/userinfo",
                    "endSessionEndpoint": "https://example.com/endsession",
                    "revocationEndpoint": "https://example.com/revoke",
                    "pingEndsessionEndpoint": "https://example.com/ping-endsession",
                    "pushedAuthorizationRequestEndpoint": "https://example.com/par",
                    "deviceAuthorizationEndpoint": "https://example.com/device_authorization"
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    /// Extracts the `OidcClientConfig` registered on `OidcModule.config` from a built client.
    private func oidcClientConfig(of client: OidcWebClient) -> OidcClientConfig? {
        client.config.modules.first(where: { $0.config is OidcClientConfig })?.config as? OidcClientConfig
    }

    // MARK: - Success cases

    func testCreateOidcWebClient_success_minimalRequiredFields() {
        let result = OidcWebClient.createOidcWebClient(json: minimalJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcWebClient_success_allFields() {
        let result = OidcWebClient.createOidcWebClient(json: fullJson)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Expected success, got: \(error)")
        }
    }

    func testCreateOidcWebClient_unknownFieldsSilentlyIgnored() {
        var json = minimalJson
        json["unknownField"] = "ignored"
        json["serverUrl"] = "https://example.com/am"

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success: break
        case .failure(let error): XCTFail("Unknown fields should be silently ignored, got: \(error)")
        }
    }

    // MARK: - timeout

    func testCreateOidcWebClient_timeoutConversion() {
        var json = minimalJson
        json["timeout"] = 20000

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(client.config.timeout, 20.0, accuracy: 0.001)
    }

    func testCreateOidcWebClient_timeoutDefault() {
        let result = OidcWebClient.createOidcWebClient(json: minimalJson)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(client.config.timeout, 15.0, accuracy: 0.001)
    }

    func testCreateOidcWebClient_failure_timeoutWrongType() {
        var json = minimalJson
        json["timeout"] = "20000"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)"); return
        }
        XCTAssertEqual(field, "timeout")
    }

    // MARK: - log

    func testCreateOidcWebClient_logMapping_debug() {
        var json = minimalJson
        json["log"] = "DEBUG"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.config.logger is StandardLogger)
    }

    func testCreateOidcWebClient_logMapping_warn() {
        var json = minimalJson
        json["log"] = "WARN"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(client.config.logger is WarningLogger)
    }

    func testCreateOidcWebClient_logWrongType_softFault_succeeds() {
        var json = minimalJson
        json["log"] = 1

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success when log has wrong type (soft fault), got: \(error)")
        }
    }

    // MARK: - oidc (required)

    func testCreateOidcWebClient_failure_missingOidc() {
        var json = minimalJson
        json.removeValue(forKey: "oidc")

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateOidcWebClient_failure_oidcWrongType() {
        var json = minimalJson
        json["oidc"] = "not-an-object"

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateOidcWebClient_failure_missingClientId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "clientId")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    func testCreateOidcWebClient_failure_missingDiscoveryEndpoint() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "discoveryEndpoint")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    // MARK: - openId-only (skip-discovery)

    func testCreateOidcWebClient_success_openIdOnly_noDiscoveryEndpoint() {
        let result = OidcWebClient.createOidcWebClient(json: openIdOnlyJson)
        guard case .success(let client) = result else {
            XCTFail("Expected success, got: \(result)"); return
        }
        guard let oidcClientConfig = oidcClientConfig(of: client) else {
            XCTFail("Expected an OidcClientConfig module to be registered"); return
        }

        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "")
        XCTAssertEqual(oidcClientConfig.openId?.authorizationEndpoint, "https://example.com/authorize")
        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, "https://example.com/token")
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, "https://example.com/userinfo")
        XCTAssertEqual(oidcClientConfig.openId?.endSessionEndpoint, "https://example.com/endsession")
        XCTAssertEqual(oidcClientConfig.openId?.revocationEndpoint, "https://example.com/revoke")
        XCTAssertEqual(oidcClientConfig.openId?.pingEndsessionEndpoint, "https://example.com/ping-endsession")
        XCTAssertEqual(oidcClientConfig.openId?.pushedAuthorizationRequestEndpoint, "https://example.com/par")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, "https://example.com/device_authorization")
    }

    func testCreateOidcWebClient_success_openIdOnly_lenient_tokenEndpointOnly() {
        var json = openIdOnlyJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = ["tokenEndpoint": "https://example.com/token"] as [String: Any]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success, got: \(result)"); return
        }
        guard let oidcClientConfig = oidcClientConfig(of: client) else {
            XCTFail("Expected an OidcClientConfig module to be registered"); return
        }

        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "")
        XCTAssertEqual(oidcClientConfig.openId?.tokenEndpoint, "https://example.com/token")
        XCTAssertEqual(oidcClientConfig.openId?.authorizationEndpoint, "", "Non-required endpoints default to an empty string in the no-discovery form")
        XCTAssertEqual(oidcClientConfig.openId?.userinfoEndpoint, "")
        XCTAssertEqual(oidcClientConfig.openId?.deviceAuthorizationEndpoint, nil)
    }

    func testCreateOidcWebClient_failure_openIdOnly_missingRequiredSubfield() {
        var json = openIdOnlyJson
        var oidc = json["oidc"] as! [String: Any]
        var openId = oidc["openId"] as! [String: Any]
        openId.removeValue(forKey: "tokenEndpoint")
        oidc["openId"] = openId
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.openId.tokenEndpoint), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.openId.tokenEndpoint")
    }

    func testCreateOidcWebClient_success_discoveryEndpointAndOpenIdOverride_unchanged() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["openId"] = [
            "tokenEndpoint": "https://example.com/override/token"
        ] as [String: Any]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .success(let client) = result else {
            XCTFail("Expected success, got: \(result)"); return
        }
        guard let oidcClientConfig = oidcClientConfig(of: client) else {
            XCTFail("Expected an OidcClientConfig module to be registered"); return
        }

        XCTAssertEqual(oidcClientConfig.discoveryEndpoint, "https://example.com/.well-known/openid-configuration")
        XCTAssertNil(oidcClientConfig.openId, "openId must stay nil until discovery runs — only openIdOverride captures the JSON override")

        var discovered = OpenIdConfiguration(
            authorizationEndpoint: "https://discovered.example.com/authorize",
            tokenEndpoint: "https://discovered.example.com/token",
            userinfoEndpoint: "https://discovered.example.com/userinfo",
            endSessionEndpoint: "https://discovered.example.com/endsession",
            revocationEndpoint: "https://discovered.example.com/revoke"
        )
        oidcClientConfig.openIdOverride?(&discovered)

        XCTAssertEqual(discovered.tokenEndpoint, "https://example.com/override/token")
        XCTAssertEqual(discovered.authorizationEndpoint, "https://discovered.example.com/authorize", "Non-overridden fields must remain untouched")
    }

    func testCreateOidcWebClient_failure_missingScopes() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "scopes")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateOidcWebClient_failure_missingRedirectUri() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "redirectUri")
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    func testCreateOidcWebClient_failure_scopesNotStringArray() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["scopes"] = [1, 2, 3]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateOidcWebClient_failure_additionalParametersNonStringValue() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["additionalParameters"] = ["key": 123]
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType for additionalParameters, got: \(result)"); return
        }
        XCTAssertTrue(field.hasPrefix("oidc.additionalParameters"))
    }

    // MARK: - par

    func testCreateOidcWebClient_par_true_accepted() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = true
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success with par=true, got: \(error)")
        }
    }

    func testCreateOidcWebClient_failure_par_wrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = "yes"
        json["oidc"] = oidc

        let result = OidcWebClient.createOidcWebClient(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.par), got: \(result)"); return
        }
        XCTAssertEqual(field, "oidc.par")
    }
}
