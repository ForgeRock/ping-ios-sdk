//
//  DaVinciJsonConfigTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingDavinci
@testable import PingOidc
@testable import PingLogger

final class DaVinciJsonConfigTests: XCTestCase, @unchecked Sendable {

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
            "timeout": 5000,
            "log": "DEBUG",
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid", "profile"],
                "redirectUri": "myapp://callback",
                "refreshThreshold": 30,
                "loginHint": "user@example.com",
                "state": "my-state",
                "nonce": "my-nonce",
                "display": "page",
                "prompt": "login",
                "uiLocales": "en-US",
                "acrValues": "Level3",
                "additionalParameters": ["custom": "value"]
            ] as [String: Any]
        ]
    }

    // MARK: - Success cases

    func testCreateDaVinci_success_minimalRequiredFields() {
        let result = DaVinci.createDaVinci(json: minimalJson)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testCreateDaVinci_success_allFields() {
        let result = DaVinci.createDaVinci(json: fullJson)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testCreateDaVinci_serverUrlIgnored() {
        var json = minimalJson
        json["serverUrl"] = "https://example.com/am"
        json["realm"] = "alpha"

        let result = DaVinci.createDaVinci(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("serverUrl should be silently ignored for DaVinci, got: \(error)")
        }
    }

    func testCreateDaVinci_unknownFieldsSilentlyIgnored() {
        var json = minimalJson
        json["unknownField"] = "ignored"

        let result = DaVinci.createDaVinci(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Unknown fields should be ignored, got: \(error)")
        }
    }

    // MARK: - timeout

    func testCreateDaVinci_timeoutConversion() {
        var json = minimalJson
        json["timeout"] = 5000

        let result = DaVinci.createDaVinci(json: json)
        guard case .success(let daVinci) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(daVinci.config.timeout, 5.0, accuracy: 0.001)
    }

    func testCreateDaVinci_timeoutDefault() {
        let result = DaVinci.createDaVinci(json: minimalJson)
        guard case .success(let daVinci) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertEqual(daVinci.config.timeout, 15.0, accuracy: 0.001)
    }

    func testCreateDaVinci_failure_timeoutWrongType() {
        var json = minimalJson
        json["timeout"] = "5000"

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)")
            return
        }
        XCTAssertEqual(field, "timeout")
    }

    // MARK: - log

    func testCreateDaVinci_logMapping_error() {
        var json = minimalJson
        json["log"] = "ERROR"

        let result = DaVinci.createDaVinci(json: json)
        guard case .success(let daVinci) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(daVinci.config.logger is WarningLogger)
    }

    func testCreateDaVinci_logMapping_debug() {
        var json = minimalJson
        json["log"] = "DEBUG"

        let result = DaVinci.createDaVinci(json: json)
        guard case .success(let daVinci) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(daVinci.config.logger is StandardLogger)
    }

    func testCreateDaVinci_logWrongType_softFault_succeeds() {
        var json = minimalJson
        json["log"] = 1

        let result = DaVinci.createDaVinci(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success when log has wrong type (soft fault), got: \(error)")
        }
    }

    // MARK: - oidc (required)

    func testCreateDaVinci_failure_missingOidc() {
        var json = minimalJson
        json.removeValue(forKey: "oidc")

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateDaVinci_failure_oidcWrongType() {
        var json = minimalJson
        json["oidc"] = "not-an-object"

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    func testCreateDaVinci_failure_missingClientId() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "clientId")
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    func testCreateDaVinci_failure_missingDiscoveryEndpoint() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "discoveryEndpoint")
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateDaVinci_failure_missingScopes() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "scopes")
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateDaVinci_failure_missingRedirectUri() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "redirectUri")
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    func testCreateDaVinci_failure_scopesNotStringArray() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["scopes"] = [1, 2, 3]
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateDaVinci_failure_additionalParametersNonStringValue() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["additionalParameters"] = ["key": 123]
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType for additionalParameters, got: \(result)")
            return
        }
        XCTAssertTrue(field.hasPrefix("oidc.additionalParameters"))
    }

    func testCreateDaVinci_refreshThresholdSet() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["refreshThreshold"] = 30
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got: \(error)")
        }
    }

    // MARK: - par

    func testCreateDaVinci_par_true_accepted() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = true
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success with par=true, got: \(error)")
        }
    }

    func testCreateDaVinci_failure_par_wrongType() {
        var json = minimalJson
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = "yes"
        json["oidc"] = oidc

        let result = DaVinci.createDaVinci(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.par), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.par")
    }
}
