//
//  PingFido2Tests.swift
//  PingFido2Tests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido2
@testable import PingJourney
@testable import PingOrchestrate
import AuthenticationServices

class PingFido2Tests: XCTestCase {

    var fido2: Fido2!
    
    override func setUp() {
        super.setUp()
        fido2 = Fido2()
    }
    
    override func tearDown() {
        fido2 = nil
        super.tearDown()
    }

    func testRegister() {
        let options: [String: Any] = [
            "rp": [
                "id": "example.com",
                "name": "Example Corp"
            ],
            "user": [
                "id": "testuser",
                "name": "testuser",
                "displayName": "Test User"
            ],
            "challenge": "someChallenge",
            "pubKeyCredParams": [
                ["type": "public-key", "alg": -7]
            ]
        ]
        
        let expectation = self.expectation(description: "FIDO2 registration expectation")
        
        fido2.register(options: options, window: UIWindow()) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("FIDO2 registration failed with error: \(error.localizedDescription)")
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testAuthenticate() {
        let options: [String: Any] = [
            "challenge": "someChallenge",
            "rpId": "example.com"
        ]
        
        let expectation = self.expectation(description: "FIDO2 authentication expectation")
        
        fido2.authenticate(options: options, window: UIWindow()) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("FIDO2 authentication failed with error: \(error.localizedDescription)")
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFido2RegistrationCallbackTransform() {
        let callback = Fido2RegistrationCallback()
        let input: [String: Any] = [
            FidoConstants.FIELD_CHALLENGE: "someChallenge",
            FidoConstants.FIELD_RELYING_PARTY_NAME: "Example Corp",
            FidoConstants.FIELD_RELYING_PARTY_ID_INTERNAL: "example.com",
            FidoConstants.FIELD_USER_ID: "testuser",
            FidoConstants.FIELD_USER_NAME: "testuser",
            FidoConstants.FIELD_DISPLAY_NAME: "Test User",
            FidoConstants.FIELD_PUB_KEY_CRED_PARAMS_INTERNAL: [
                [FidoConstants.FIELD_TYPE: "public-key", FidoConstants.FIELD_ALG: -7]
            ]
        ]
        
        let output = callback.transform(input)
        
        XCTAssertNotNil(output)
        XCTAssertEqual(output[FidoConstants.FIELD_CHALLENGE] as? String, "someChallenge")
        // Add more assertions here
    }
    
    func testFido2AuthenticationCallbackTransform() {
        let callback = Fido2AuthenticationCallback()
        let input: [String: Any] = [
            FidoConstants.FIELD_CHALLENGE: "someChallenge",
            FidoConstants.FIELD_RELYING_PARTY_ID_INTERNAL: "example.com"
        ]
        
        let output = callback.transform(input)
        
        XCTAssertNotNil(output)
        XCTAssertEqual(output[FidoConstants.FIELD_CHALLENGE] as? String, "someChallenge")
        // Add more assertions here
    }
    
    func testHandleError() {
        let callback = Fido2Callback()
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode
        
        let error = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue, userInfo: nil)
        callback.handleError(error: error)
        
        XCTAssertEqual(hiddenValueCallback.value, "ERROR::NotAllowedError:The operation was canceled.")
    }
    
    func testFido2RegistrationCallbackInit() {
        let callback = Fido2RegistrationCallback()
        let data: [String: Any] = [
            FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE: true,
            FidoConstants.FIELD_CHALLENGE: "someChallenge"
        ]
        callback.initValue(name: FidoConstants.FIELD_DATA, value: data)
        XCTAssertTrue(callback.publicKeyCredentialCreationOptions.keys.contains(FidoConstants.FIELD_CHALLENGE))
    }
    
    func testFido2AuthenticationCallbackInit() {
        let callback = Fido2AuthenticationCallback()
        let data: [String: Any] = [
            FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE: true,
            FidoConstants.FIELD_CHALLENGE: "someChallenge"
        ]
        callback.initValue(name: FidoConstants.FIELD_DATA, value: data)
        XCTAssertTrue(callback.publicKeyCredentialRequestOptions.keys.contains(FidoConstants.FIELD_CHALLENGE))
    }
}
