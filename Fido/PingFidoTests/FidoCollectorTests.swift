
//
//  FidoCollectorTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido

class FidoCollectorTests: XCTestCase {
    
    func testGetCollector() {
        // Test registration collector
        let registrationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_REGISTER,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]
        ]
        let registrationCollector = try? AbstractFidoCollector.getCollector(with: registrationJson)
        XCTAssertTrue(registrationCollector is FidoRegistrationCollector)
        
        // Test authentication collector
        let authenticationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_AUTHENTICATE,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]
        ]
        let authenticationCollector = try? AbstractFidoCollector.getCollector(with: authenticationJson)
        XCTAssertTrue(authenticationCollector is FidoAuthenticationCollector)
        
        // Test invalid action
        let invalidActionJson: [String: Any] = ["action": "invalid"]
        XCTAssertThrowsError(try AbstractFidoCollector.getCollector(with: invalidActionJson)) {
            let fidoError = $0 as? FidoError
            XCTAssertEqual(fidoError, .unsupportedAction("invalid"))
        }
        
        // Test missing action
        let missingActionJson: [String: Any] = [:]
        XCTAssertThrowsError(try AbstractFidoCollector.getCollector(with: missingActionJson)) {
            let fidoError = $0 as? FidoError
            XCTAssertEqual(fidoError, .invalidAction)
        }
    }
    
    // MARK: - FidoAuthenticationCollector Tests
    
    func testFidoAuthenticationCollectorInit() {
        let json: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]
        ]
        let collector = FidoAuthenticationCollector(with: json)
        XCTAssertNotNil(collector)
        XCTAssertFalse(collector.publicKeyCredentialRequestOptions.isEmpty)
        let invalidJson: [String: Any] = [:]
        let collector2 = FidoAuthenticationCollector(with: invalidJson)
        XCTAssertTrue(collector2.publicKeyCredentialRequestOptions.isEmpty)
    }
    
    func testFidoAuthenticationCollectorPayload() {
        // ... (this test remains unchanged)
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertNil(collector.payload())
        
        collector.assertionValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ASSERTION_VALUE] as? [String: String], ["test": "test"])
    }
    
    @MainActor // Ensure UI-related code runs on main actor
    func testFidoAuthenticationCollectorAuthenticate() async { // Removed 'throws'
        let mockFido = MockFido()
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        collector.fido = mockFido // Inject mock
        
        // --- Test success ---
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_AUTHENTICATOR_DATA: "authenticatorData".data(using: .utf8)!,
            FidoConstants.FIELD_SIGNATURE: "signature".data(using: .utf8)!,
            FidoConstants.FIELD_USER_HANDLE: "userHandle".data(using: .utf8)!
        ]
        mockFido.authenticationResult = .success(successResponse)
        
        // Call the async version and assert success via Result
        let result = await collector.authenticate(window: MockASPresentationAnchor())
        
        switch result {
        case .success(let resultAssertionValue):
            // Check if the returned value matches expectations (based on internal logic)
            XCTAssertNotNil(resultAssertionValue)
            // Example check - adjust based on your actual construction logic and expected Base64URL
            XCTAssertEqual(resultAssertionValue[FidoConstants.FIELD_ID] as? String, "rawId".data(using: .utf8)!.base64urlEncodedString())
            
            // Also verify the internal state was set for payload()
            XCTAssertNotNil(collector.assertionValue)
            XCTAssertEqual(collector.assertionValue?[FidoConstants.FIELD_ID] as? String, resultAssertionValue[FidoConstants.FIELD_ID] as? String)
        case .failure(let error):
            XCTFail("Expected authenticate to succeed, but it failed with \(error).")
        }
        
        // --- Test failure ---
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)
        
        // Call the async version and assert failure via Result
        let failureResult = await collector.authenticate(window: MockASPresentationAnchor())
        
        switch failureResult {
        case .success:
            XCTFail("Expected authenticate to fail with FidoError.invalidChallenge, but it succeeded.")
        case .failure(let error):
            guard let fidoError = error as? FidoError else {
                XCTFail("Expected FidoError.invalidChallenge, but got \(error).")
                return
            }
            XCTAssertEqual(fidoError, .invalidChallenge)
        }
    }
    
    // MARK: - FidoRegistrationCollector Tests
    
    func testFidoRegistrationCollectorInit() {
        let json: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]
        ]
        let collector = FidoRegistrationCollector(with: json)
        XCTAssertNotNil(collector)
        XCTAssertFalse(collector.publicKeyCredentialCreationOptions.isEmpty)
        let invalidJson: [String: Any] = [:]
        let collector2 = FidoRegistrationCollector(with: invalidJson)
        XCTAssertTrue(collector2.publicKeyCredentialCreationOptions.isEmpty)
    }
    
    func testFidoRegistrationCollectorPayload() {
        // ... (this test remains unchanged)
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        XCTAssertNil(collector.payload())
        
        collector.attestationValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ATTESTATION_VALUE] as? [String: String], ["test": "test"])
    }
    
    @MainActor // Ensure UI-related code runs on main actor
    func testFidoRegistrationCollectorRegister() async { // Removed 'throws'
        let mockFido = MockFido()
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        collector.fido = mockFido // Inject mock
        
        // --- Test success ---
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]
        mockFido.registrationResult = .success(successResponse)
        
        // Call the async version and assert success via Result
        let result = await collector.register(window: MockASPresentationAnchor())
        
        switch result {
        case .success(let resultAttestationValue):
            // Check if the returned value matches expectations
            XCTAssertNotNil(resultAttestationValue)
            // Example check - adjust based on your actual construction logic and expected Base64URL
            XCTAssertEqual(resultAttestationValue[FidoConstants.FIELD_ID] as? String, "rawId".data(using: .utf8)!.base64urlEncodedString())
            
            // Also verify the internal state was set for payload()
            XCTAssertNotNil(collector.attestationValue)
            XCTAssertEqual(collector.attestationValue?[FidoConstants.FIELD_ID] as? String, resultAttestationValue[FidoConstants.FIELD_ID] as? String)
        case .failure(let error):
            XCTFail("Expected register to succeed, but it failed with \(error).")
        }
        
        // --- Test failure ---
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)
        
        // Call the async version and assert failure via Result
        let failureResult = await collector.register(window: MockASPresentationAnchor())
        
        switch failureResult {
        case .success:
            XCTFail("Expected register to fail with FidoError.invalidChallenge, but it succeeded.")
        case .failure(let error):
            guard let fidoError = error as? FidoError else {
                XCTFail("Expected FidoError.invalidChallenge, but got \(error).")
                return
            }
            XCTAssertEqual(fidoError, .invalidChallenge)
        }
    }
}
