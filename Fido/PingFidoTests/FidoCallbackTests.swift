
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
    
    
    @MainActor // Mark test as running on MainActor
    func testFidoRegistrationCallbackRegister() async throws {
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
        
        // Call the async version and expect it not to throw
        try await callback.register(window: MockASPresentationAnchor())
        
        // Verify the hidden value callback was set correctly (example check)
        XCTAssertFalse((hiddenValueCallback.value).starts(with: "ERROR::")) // Should not be an error
        XCTAssertTrue((hiddenValueCallback.value).contains("clientDataJSON")) // Contains expected data part

        // --- Test failure ---
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)
        
        // Assert that the specific error is thrown
        do {
            try await callback.register(window: MockASPresentationAnchor())
            XCTFail("Expected register to throw FidoError.invalidChallenge, but it did not.")
        } catch let error as FidoError {
            XCTAssertEqual(error, .invalidChallenge)
            // Verify the hidden value callback was set to an error string
             XCTAssertTrue((hiddenValueCallback.value).starts(with: "ERROR::"))
        } catch {
            XCTFail("Expected register to throw FidoError.invalidChallenge, but it threw \(error).")
        }
    }
    
    // Updated test using async/await
    @MainActor // Mark test as running on MainActor
    func testFidoAuthenticationCallbackAuthenticate() async throws {
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
        
        // Call the async version and expect it not to throw
        try await callback.authenticate(window: MockASPresentationAnchor())
        
        // Verify the hidden value callback was set correctly
        XCTAssertFalse((hiddenValueCallback.value).starts(with: "ERROR::"))
        XCTAssertTrue((hiddenValueCallback.value).contains("clientDataJSON"))

        // --- Test failure ---
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)
        
        // Assert that the specific error is thrown
        do {
            try await callback.authenticate(window: MockASPresentationAnchor())
            XCTFail("Expected authenticate to throw FidoError.invalidChallenge, but it did not.")
        } catch let error as FidoError {
            XCTAssertEqual(error, .invalidChallenge)
            // Verify the hidden value callback was set to an error string
            XCTAssertTrue((hiddenValueCallback.value).starts(with: "ERROR::"))
        } catch {
            XCTFail("Expected authenticate to throw FidoError.invalidChallenge, but it threw \(error).")
        }
    }
}
