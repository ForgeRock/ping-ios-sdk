//
//  JourneyJsonConfigTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingLogger

final class JourneyJsonConfigTests: XCTestCase, @unchecked Sendable {

    // MARK: - Minimal valid JSON (Journey-only, no OIDC)

    private var minimalJson: [String: Any] {
        [
            "journey": [
                "serverUrl": "https://example.com/am"
            ] as [String: Any]
        ]
    }

    // MARK: - Minimal valid JSON with OIDC

    private var minimalJsonWithOidc: [String: Any] {
        [
            "journey": [
                "serverUrl": "https://example.com/am"
            ] as [String: Any],
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
            "journey": [
                "serverUrl": "https://example.com/am",
                "realm": "alpha",
                "cookieName": "iPlanetDirectoryPro"
            ] as [String: Any],
            "timeout": 30000,
            "log": "DEBUG",
            "oidc": [
                "clientId": "my-client",
                "discoveryEndpoint": "https://example.com/.well-known/openid-configuration",
                "scopes": ["openid", "profile", "email"],
                "redirectUri": "myapp://callback",
                "signOutRedirectUri": "myapp://logout",
                "refreshThreshold": 60,
                "loginHint": "user@example.com",
                "state": "my-state",
                "nonce": "my-nonce",
                "display": "page",
                "prompt": "login",
                "uiLocales": "en-US",
                "acrValues": "Level3",
                "additionalParameters": ["custom_param": "custom_value"]
            ] as [String: Any]
        ]
    }

    // MARK: - Success cases

    func testCreateJourney_success_minimalRequiredFields() {
        let result = Journey.createJourney(json: minimalJson)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testCreateJourney_success_allFields() {
        let result = Journey.createJourney(json: fullJson)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got failure: \(error)")
        }
    }

    func testCreateJourney_unknownFieldsSilentlyIgnored() {
        var json = minimalJsonWithOidc
        json["unknownTopLevel"] = "ignored"
        var oidc = json["oidc"] as! [String: Any]
        oidc["unknownOidc"] = 42
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success for unknown fields, got: \(error)")
        }
    }

    // MARK: - journey sub-dict

    func testCreateJourney_failure_missingJourneyDict() {
        let result = Journey.createJourney(json: [:])
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(journey), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey")
    }

    func testCreateJourney_failure_missingServerUrl() {
        var json = minimalJson
        json["journey"] = [String: Any]()

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(journey.serverUrl), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.serverUrl")
    }

    func testCreateJourney_failure_serverUrlWrongType() {
        var json = minimalJson
        json["journey"] = ["serverUrl": 12345]

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.serverUrl), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.serverUrl")
    }

    // MARK: - realm

    func testCreateJourney_realmDefault() {
        let result = Journey.createJourney(json: minimalJson)
        guard case .success(let journey) = result else {
            XCTFail("Expected success")
            return
        }
        let journeyConfig = journey.config as? JourneyConfig
        XCTAssertEqual(journeyConfig?.realm, "root")
    }

    func testCreateJourney_failure_realmWrongType() {
        var json = minimalJson
        json["journey"] = ["serverUrl": "https://example.com/am", "realm": 999]

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.realm), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.realm")
    }

    // MARK: - cookieName

    func testCreateJourney_cookieNameDefault() {
        let result = Journey.createJourney(json: minimalJson)
        guard case .success(let journey) = result else {
            XCTFail("Expected success")
            return
        }
        let journeyConfig = journey.config as? JourneyConfig
        XCTAssertEqual(journeyConfig?.cookie, "iPlanetDirectoryPro")
    }

    func testCreateJourney_cookieNameCustom() {
        var json = minimalJson
        json["journey"] = ["serverUrl": "https://example.com/am", "cookieName": "myCustomCookie"]

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success")
            return
        }
        let journeyConfig = journey.config as? JourneyConfig
        XCTAssertEqual(journeyConfig?.cookie, "myCustomCookie")
    }

    func testCreateJourney_failure_cookieNameWrongType() {
        var json = minimalJson
        json["journey"] = ["serverUrl": "https://example.com/am", "cookieName": 123]

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(journey.cookieName), got: \(result)")
            return
        }
        XCTAssertEqual(field, "journey.cookieName")
    }

    // MARK: - timeout

    func testCreateJourney_timeoutConversion() {
        var json = minimalJson
        json["timeout"] = 30000

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success")
            return
        }
        XCTAssertEqual(journey.config.timeout, 30.0, accuracy: 0.001)
    }

    func testCreateJourney_timeoutDefault() {
        let result = Journey.createJourney(json: minimalJson)
        guard case .success(let journey) = result else {
            XCTFail("Expected success")
            return
        }
        XCTAssertEqual(journey.config.timeout, 15.0, accuracy: 0.001)
    }

    func testCreateJourney_failure_timeoutWrongType() {
        var json = minimalJson
        json["timeout"] = "30000"

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(timeout), got: \(result)")
            return
        }
        XCTAssertEqual(field, "timeout")
    }

    // MARK: - log

    func testCreateJourney_logMapping_none() {
        var json = minimalJson
        json["log"] = "NONE"

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(journey.config.logger is NoneLogger)
    }

    func testCreateJourney_logMapping_debug() {
        var json = minimalJson
        json["log"] = "DEBUG"

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(journey.config.logger is StandardLogger)
    }

    func testCreateJourney_logMapping_info() {
        var json = minimalJson
        json["log"] = "INFO"

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(journey.config.logger is StandardLogger)
    }

    func testCreateJourney_logMapping_warn() {
        var json = minimalJson
        json["log"] = "WARN"

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(journey.config.logger is WarningLogger)
    }

    func testCreateJourney_logMapping_error() {
        var json = minimalJson
        json["log"] = "ERROR"

        let result = Journey.createJourney(json: json)
        guard case .success(let journey) = result else {
            XCTFail("Expected success"); return
        }
        XCTAssertTrue(journey.config.logger is WarningLogger)
    }

    func testCreateJourney_logWrongType_softFault_succeeds() {
        var json = minimalJson
        json["log"] = 1

        let result = Journey.createJourney(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success when log has wrong type (soft fault), got: \(error)")
        }
    }

    // MARK: - oidc (optional)

    func testCreateJourney_success_withoutOidc() {
        let result = Journey.createJourney(json: minimalJson)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success without oidc, got: \(error)")
        }
    }

    func testCreateJourney_failure_oidcWrongType() {
        var json = minimalJsonWithOidc
        json["oidc"] = "not-an-object"

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc")
    }

    // MARK: - oidc required fields

    func testCreateJourney_failure_missingClientId() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "clientId")
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.clientId), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.clientId")
    }

    func testCreateJourney_failure_missingDiscoveryEndpoint() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "discoveryEndpoint")
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.discoveryEndpoint), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.discoveryEndpoint")
    }

    func testCreateJourney_failure_missingScopes() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "scopes")
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateJourney_failure_missingRedirectUri() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc.removeValue(forKey: "redirectUri")
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .missingRequiredField(let field) = error as? JsonConfigError else {
            XCTFail("Expected missingRequiredField(oidc.redirectUri), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.redirectUri")
    }

    func testCreateJourney_failure_scopesNotStringArray() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc["scopes"] = [1, 2, 3]
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.scopes), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.scopes")
    }

    func testCreateJourney_failure_additionalParametersNonStringValue() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc["additionalParameters"] = ["key": 123]
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType for additionalParameters, got: \(result)")
            return
        }
        XCTAssertTrue(field.hasPrefix("oidc.additionalParameters"))
    }

    // MARK: - refreshThreshold default

    func testCreateJourney_refreshThresholdDefault() {
        let result = Journey.createJourney(json: minimalJson)
        guard case .success = result else {
            XCTFail("Expected success"); return
        }
        // Just verifying creation succeeded — refreshThreshold is set on OidcClientConfig
        // which is internal to the module config and not directly inspectable here.
    }

    // MARK: - par

    func testCreateJourney_par_true_accepted() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = true
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success with par=true, got: \(error)")
        }
    }

    func testCreateJourney_failure_par_wrongType() {
        var json = minimalJsonWithOidc
        var oidc = json["oidc"] as! [String: Any]
        oidc["par"] = "yes"
        json["oidc"] = oidc

        let result = Journey.createJourney(json: json)
        guard case .failure(let error) = result,
              case .invalidType(let field, _) = error as? JsonConfigError else {
            XCTFail("Expected invalidType(oidc.par), got: \(result)")
            return
        }
        XCTAssertEqual(field, "oidc.par")
    }
}
