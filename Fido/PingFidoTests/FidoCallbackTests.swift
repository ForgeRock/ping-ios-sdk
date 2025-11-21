
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
@testable import PingJourneyPlugin
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
    
    
    @MainActor // Mark test as running on MainActor
    func testFidoRegistrationCallbackRegister() async { // Removed 'throws'
        let callback = FidoRegistrationCallback()
        callback.fido = mockFido // Inject mock
        
        // Setup necessary Journey context for the callback
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode
        
        // --- Test success ---
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]
        mockFido.registrationResult = .success(successResponse)
        
        // Call the async version and check the Result
        let result = await callback.register(window: MockASPresentationAnchor())
        
        switch result {
        case .success(let responseDict):
            // Optional: Assert specific things about the response if needed
            XCTAssertEqual(responseDict[FidoConstants.FIELD_RAW_ID] as? Data, "rawId".data(using: .utf8)!)
            // Verify the side effect on hiddenValueCallback
            XCTAssertFalse((hiddenValueCallback.value ?? "").starts(with: "ERROR::"))
            XCTAssertTrue((hiddenValueCallback.value ?? "").contains("clientDataJSON"))
        case .failure(let error):
            XCTFail("Expected register to succeed, but it failed with \(error).")
        }
        
        // --- Test failure ---
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)
        
        // Call the async version and check the Result for failure
        let failureResult = await callback.register(window: MockASPresentationAnchor())
        
        switch failureResult {
        case .success:
            XCTFail("Expected register to fail with FidoError.invalidChallenge, but it succeeded.")
        case .failure(let error):
            guard let fidoError = error as? FidoError else {
                XCTFail("Expected FidoError.invalidChallenge, but got \(error).")
                return
            }
            XCTAssertEqual(fidoError, .invalidChallenge)
            // Verify the side effect on hiddenValueCallback
            XCTAssertTrue((hiddenValueCallback.value ?? "").starts(with: "ERROR::"))
        }
    }
    
    @MainActor // Mark test as running on MainActor
    func testFidoAuthenticationCallbackAuthenticate() async { // Removed 'throws'
        let callback = FidoAuthenticationCallback()
        callback.fido = mockFido // Inject mock
        
        // Setup necessary Journey context
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode
        
        // --- Test success ---
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_AUTHENTICATOR_DATA: "authenticatorData".data(using: .utf8)!,
            FidoConstants.FIELD_SIGNATURE: "signature".data(using: .utf8)!,
            FidoConstants.FIELD_USER_HANDLE: "userHandle".data(using: .utf8)!
        ]
        mockFido.authenticationResult = .success(successResponse)
        
        // Call the async version and check the Result
        let result = await callback.authenticate(window: MockASPresentationAnchor())
        
        switch result {
        case .success(let responseDict):
            // Optional: Assert specific things about the response if needed
            XCTAssertEqual(responseDict[FidoConstants.FIELD_RAW_ID] as? Data, "rawId".data(using: .utf8)!)
            // Verify the side effect on hiddenValueCallback
            XCTAssertFalse((hiddenValueCallback.value ?? "").starts(with: "ERROR::"))
            XCTAssertTrue((hiddenValueCallback.value ?? "").contains("clientDataJSON"))
        case .failure(let error):
            XCTFail("Expected authenticate to succeed, but it failed with \(error).")
        }
        
        // --- Test failure ---
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)
        
        // Call the async version and check the Result for failure
        let failureResult = await callback.authenticate(window: MockASPresentationAnchor())
        
        switch failureResult {
        case .success:
            XCTFail("Expected authenticate to fail with FidoError.invalidChallenge, but it succeeded.")
        case .failure(let error):
            guard let fidoError = error as? FidoError else {
                XCTFail("Expected FidoError.invalidChallenge, but got \(error).")
                return
            }
            XCTAssertEqual(fidoError, .invalidChallenge)
            // Verify the side effect on hiddenValueCallback
            XCTAssertTrue((hiddenValueCallback.value ?? "").starts(with: "ERROR::"))
        }
    }
}
