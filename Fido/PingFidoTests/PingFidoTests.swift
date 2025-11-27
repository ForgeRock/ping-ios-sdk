//
//  PingFidoTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido
@testable import PingJourneyPlugin
@testable import PingJourney
@testable import PingOrchestrate
import AuthenticationServices

class PingFidoTests: XCTestCase {

    var fido: Fido!
    
    override func setUp() {
        super.setUp()
        fido = Fido()
    }
    
    override func tearDown() {
        fido = nil
        super.tearDown()
    }

    @MainActor func testRegisterAssosiatedDomainError() {
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
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "pubKeyCredParams": [
                ["type": "public-key", "alg": -7]
            ]
        ]
        
        let expectation = self.expectation(description: "FIDO registration expectation")
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let scene = windowScene else {
            XCTFail("No UIWindowScene available")
            return
        }
        let window = UIWindow(windowScene: scene)
        
        fido.register(options: options, window: window) { result in
            switch result {
            case .success( _):
                XCTFail("Expected to fail, got success")
                expectation.fulfill()
            case .failure(let error):
                print("Authentication error: \(error.localizedDescription)")
                XCTAssertTrue(error.localizedDescription.contains("not associated with domain example.com"), "Error message: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    @MainActor func testAuthenticateAssosiatedDomainError() {
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com"
        ]
        
        let expectation = self.expectation(description: "FIDO authentication expectation")
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        guard let scene = windowScene else {
            XCTFail("No UIWindowScene available")
            return
        }
        let window = UIWindow(windowScene: scene)
        
        fido.authenticate(options: options, window: window) { result in
            switch result {
            case .success( _):
                XCTFail("Expected to fail, got success")
                expectation.fulfill()
            case .failure(let error):
                print("Authentication error: \(error.localizedDescription)")
                XCTAssertTrue(error.localizedDescription.contains("not associated with domain example.com"), "Error message: \(error.localizedDescription)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFidoRegistrationCallbackTransform() {
        let callback = FidoRegistrationCallback()
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
    
    func testFidoAuthenticationCallbackTransform() {
        let callback = FidoAuthenticationCallback()
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
        let callback = FidoCallback()
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
    
    func testFidoRegistrationCallbackInit() {
        let callback = FidoRegistrationCallback()
        let data: [String: Any] = [
            FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE: true,
            FidoConstants.FIELD_CHALLENGE: "someChallenge"
        ]
        callback.initValue(name: FidoConstants.FIELD_DATA, value: data)
        XCTAssertTrue(callback.publicKeyCredentialCreationOptions.keys.contains(FidoConstants.FIELD_CHALLENGE))
    }
    
    func testFidoAuthenticationCallbackInit() {
        let callback = FidoAuthenticationCallback()
        let data: [String: Any] = [
            FidoConstants.FIELD_SUPPORTS_JSON_RESPONSE: true,
            FidoConstants.FIELD_CHALLENGE: "someChallenge"
        ]
        callback.initValue(name: FidoConstants.FIELD_DATA, value: data)
        XCTAssertTrue(callback.publicKeyCredentialRequestOptions.keys.contains(FidoConstants.FIELD_CHALLENGE))
    }
}
