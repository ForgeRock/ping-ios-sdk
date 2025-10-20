
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
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertNil(collector.payload())
        
        collector.assertionValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ASSERTION_VALUE] as? [String: String], ["test": "test"])
    }
    
    func testFidoAuthenticationCollectorAuthenticate() {
        let mockFido = MockFido()
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        collector.fido = mockFido
        
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
        collector.authenticate(window: MockASPresentationAnchor()) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                expectation.fulfill()
            case .failure:
                XCTFail("Expected success, got failure")
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido.authenticationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO authentication failure")
        collector.authenticate(window: MockASPresentationAnchor()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure, got success")
            case .failure(let error):
                XCTAssertEqual(error as? FidoError, .invalidChallenge)
                failureExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
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
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        XCTAssertNil(collector.payload())
        
        collector.attestationValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ATTESTATION_VALUE] as? [String: String], ["test": "test"])
    }
    
    func testFidoRegistrationCollectorRegister() {
        let mockFido = MockFido()
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        collector.fido = mockFido
        
        // Test success
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]
        mockFido.registrationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO registration success")
        collector.register(window: MockASPresentationAnchor()) { result in
            switch result {
            case .success(let response):
                XCTAssertNotNil(response)
                expectation.fulfill()
            case .failure:
                XCTFail("Expected success, got failure")
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Test failure
        mockFido.registrationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO registration failure")
        collector.register(window: MockASPresentationAnchor()) { result in
            switch result {
            case .success:
                XCTFail("Expected failure, got success")
            case .failure(let error):
                XCTAssertEqual(error as? FidoError, .invalidChallenge)
                failureExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
}
