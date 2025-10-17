
//
//  Fido2CallbackTests.swift
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

class Fido2CallbackTests: XCTestCase {

    var mockFido2: MockFido2!
    
    override func setUp() {
        super.setUp()
        mockFido2 = MockFido2()
    }
    
    override func tearDown() {
        mockFido2 = nil
        super.tearDown()
    }
    
    func testFido2RegistrationCallbackRegister() {
        let callback = Fido2RegistrationCallback()
        callback.fido2 = mockFido2
        
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode
        
        // Test success
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]
        mockFido2.registrationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO2 registration success")
        callback.register(window: MockASPresentationAnchor()) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido2.registrationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO2 registration failure")
        callback.register(window: MockASPresentationAnchor()) { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error as? FidoError, .invalidChallenge)
            failureExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFido2AuthenticationCallbackAuthenticate() {
        let callback = Fido2AuthenticationCallback()
        callback.fido2 = mockFido2
        
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode
        
        // Test success
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_AUTHENTICATOR_DATA: "authenticatorData".data(using: .utf8)!,
            FidoConstants.FIELD_SIGNATURE: "signature".data(using: .utf8)!,
            FidoConstants.FIELD_USER_HANDLE: "userHandle".data(using: .utf8)!
        ]
        mockFido2.authenticationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO2 authentication success")
        callback.authenticate(window: MockASPresentationAnchor()) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido2.authenticationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO2 authentication failure")
        callback.authenticate(window: MockASPresentationAnchor()) { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error as? FidoError, .invalidChallenge)
            failureExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
