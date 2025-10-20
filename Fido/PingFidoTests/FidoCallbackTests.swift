
//
//  FidoCallbackTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido
@testable import PingJourney

class FidoCallbackTests: XCTestCase {

    var mockFido: MockFido!
    
    override func setUp() {
        super.setUp()
        mockFido = MockFido()
    }
    
    override func tearDown() {
        mockFido = nil
        super.tearDown()
    }
    
    func testFidoRegistrationCallbackRegister() {
        let callback = FidoRegistrationCallback()
        callback.fido = mockFido
        
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
        mockFido.registrationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO registration success")
        callback.register(window: MockASPresentationAnchor()) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO registration failure")
        callback.register(window: MockASPresentationAnchor()) { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error as? FidoError, .invalidChallenge)
            failureExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testFidoAuthenticationCallbackAuthenticate() {
        let callback = FidoAuthenticationCallback()
        callback.fido = mockFido
        
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
        mockFido.authenticationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO authentication success")
        callback.authenticate(window: MockASPresentationAnchor()) { error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO authentication failure")
        callback.authenticate(window: MockASPresentationAnchor()) { error in
            XCTAssertNotNil(error)
            XCTAssertEqual(error as? FidoError, .invalidChallenge)
            failureExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
