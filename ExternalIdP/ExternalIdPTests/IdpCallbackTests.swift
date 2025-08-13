// 
//  IdpCallbackTests.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
import PingJourney
@testable import PingExternalIdP

final class IdpCallbackTests: XCTestCase {
    let json: [String: Any] = [
        "type": "IdPCallback",
        "output": [
            ["name": "provider", "value": "pingexample_siwa"],
            ["name": "clientId", "value": "com.pingidentity.PingExample"],
            ["name": "redirectUri", "value": "https://test.example.com/am/oauth2/alpha/client/form_post/pingexample_siwa"],
            ["name": "scopes", "value": ["name", "email"]],
            ["name": "nonce", "value": ""],
            ["name": "acrValues", "value": []],
            ["name": "request", "value": ""],
            ["name": "acceptsJSON", "value": true],
            ["name": "requestUri", "value": ""]
        ],
        "input": [
            ["name": "IDToken1token", "value": ""],
            ["name": "IDToken1token_type", "value": ""]
        ]
    ]
    
    func testInitValueParsesProviderFields() {
        let callback = IdpCallback()
        callback.initValue(name: JourneyConstants.provider, value: "google")
        callback.initValue(name: JourneyConstants.clientId, value: "foo")
        callback.initValue(name: JourneyConstants.redirectUri, value: "bar://callback")
        callback.initValue(name: JourneyConstants.scopes, value: ["openid", "email"])
        callback.initValue(name: JourneyConstants.nonce, value: "xyz")
        callback.initValue(name: JourneyConstants.acrValues, value: ["val1"])
        callback.initValue(name: JourneyConstants.acceptsJSON, value: true)
        
        XCTAssertEqual(callback.provider, "google")
        XCTAssertEqual(callback.clientId, "foo")
        XCTAssertEqual(callback.redirectUri, "bar://callback")
        XCTAssertEqual(callback.scopes, ["openid", "email"])
        XCTAssertEqual(callback.nonce, "xyz")
        XCTAssertEqual(callback.acrValues, ["val1"])
        XCTAssertTrue(callback.acceptsJSON)
    }
    
    func testPayloadAcceptsJSON() {
        let callback = IdpCallback()
        callback.json = json
        callback.initValue(name: JourneyConstants.acceptsJSON, value: true)
        let idpResult = IdpResult(token: "t1", additionalParameters: [JourneyConstants.acceptsJSON: "{\"token\":\"t1\"}"])
        callback.setResultForTest(idpResult) // Your test setter
        
        let payload = callback.payload()
        XCTAssertEqual(payload["type"] as? String, "IdPCallback")
        XCTAssertTrue(callback.acceptsJSON)
        
        // input should be an array of dictionaries
        guard let inputArray = payload["input"] as? [[String: Any]] else {
            XCTFail("payload input is not array")
            return
        }
        // Find the right input dict
        guard let tokenInput = inputArray.first(where: { $0["name"] as? String == "IDToken1token" }) else {
            XCTFail("IDToken1token input not found")
            return
        }
        XCTAssertEqual(tokenInput["value"] as? String, "{\"token\":\"t1\"}")
    }
    
    func testPayloadTokenType() {
        let callback = IdpCallback()
        callback.json = json
        callback.initValue(name: JourneyConstants.acceptsJSON, value: false)
        callback.setResultForTest(IdpResult(token: "abc123", additionalParameters: nil))
        callback.setTokenTypeForTest("id_token")
        let payload = callback.payload()

        XCTAssertEqual(payload["type"] as? String, "IdPCallback")
        
        // input should be an array of dictionaries
        guard let inputArray = payload["input"] as? [[String: Any]] else {
            XCTFail("payload input is not array")
            return
        }
        // Find the right input dict
        guard let tokenInput = inputArray.first(where: { $0["name"] as? String == "IDToken1token" }) else {
            XCTFail("IDToken1token input not found")
            return
        }
        XCTAssertEqual(tokenInput["value"] as? String, "abc123")
        guard let tokenType = inputArray.first(where: { $0["name"] as? String == "IDToken1token_type" }) else {
            XCTFail("IDToken1token input not found")
            return
        }
        XCTAssertEqual(tokenType["value"] as? String, "id_token")

    }
    
    func testAuthorizeWithUnknownProviderFails() async {
        let callback = IdpCallback()
        callback.initValue(name: JourneyConstants.provider, value: "unknown-idp")
        let result = await callback.authorize()
        switch result {
        case .failure(let error):
            XCTAssertTrue("\(error)".contains("unsupportedIdpException"))
        default:
            XCTFail("Expected failure for unknown provider")
        }
    }
}

extension IdpCallback {
    // Only in your test target!
    func setResultForTest(_ result: IdpResult) {
        self.result = result
    }
    func setTokenTypeForTest(_ tokenType: String) {
        self.tokenType = tokenType
    }
}
