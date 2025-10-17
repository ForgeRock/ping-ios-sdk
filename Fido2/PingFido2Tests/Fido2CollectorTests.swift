
//
//  Fido2CollectorTests.swift
//  PingFido2Tests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingFido2

class Fido2CollectorTests: XCTestCase {

    func testGetCollector() {
        // Test registration collector
        let registrationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_REGISTER,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]
        ]
        let registrationCollector = try? AbstractFido2Collector.getCollector(with: registrationJson)
        XCTAssertTrue(registrationCollector is Fido2RegistrationCollector)
        
        // Test authentication collector
        let authenticationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_AUTHENTICATE,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]
        ]
        let authenticationCollector = try? AbstractFido2Collector.getCollector(with: authenticationJson)
        XCTAssertTrue(authenticationCollector is Fido2AuthenticationCollector)
        
        // Test invalid action
        let invalidActionJson: [String: Any] = ["action": "invalid"]
        XCTAssertThrowsError(try AbstractFido2Collector.getCollector(with: invalidActionJson)) {
            let fidoError = $0 as? FidoError
            XCTAssertEqual(fidoError, .unsupportedAction("invalid"))
        }
        
        // Test missing action
        let missingActionJson: [String: Any] = [:]
        XCTAssertThrowsError(try AbstractFido2Collector.getCollector(with: missingActionJson)) {
            let fidoError = $0 as? FidoError
            XCTAssertEqual(fidoError, .invalidAction)
        }
    }
    
    // MARK: - Fido2AuthenticationCollector Tests
    
    func testFido2AuthenticationCollectorInit() {
        let json: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]
        ]
        let collector = Fido2AuthenticationCollector(with: json)
        XCTAssertNotNil(collector)
        XCTAssertFalse(collector.publicKeyCredentialRequestOptions.isEmpty)
        let invalidJson: [String: Any] = [:]
        let collector2 = Fido2AuthenticationCollector(with: invalidJson)
        XCTAssertTrue(collector2.publicKeyCredentialRequestOptions.isEmpty)
    }
    
    func testFido2AuthenticationCollectorPayload() {
        let collector = Fido2AuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertNil(collector.payload())
        
        collector.assertionValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ASSERTION_VALUE] as? [String: String], ["test": "test"])
    }
    
    func testFido2AuthenticationCollectorAuthenticate() {
        let mockFido2 = MockFido2()
        let collector = Fido2AuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        collector.fido2 = mockFido2
        
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
        mockFido2.authenticationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO2 authentication failure")
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
    
    // MARK: - Fido2RegistrationCollector Tests
    
    func testFido2RegistrationCollectorInit() {
        let json: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]
        ]
        let collector = Fido2RegistrationCollector(with: json)
        XCTAssertNotNil(collector)
        XCTAssertFalse(collector.publicKeyCredentialCreationOptions.isEmpty)
        let invalidJson: [String: Any] = [:]
        let collector2 = Fido2RegistrationCollector(with: invalidJson)
        XCTAssertTrue(collector2.publicKeyCredentialCreationOptions.isEmpty)
    }
    
    func testFido2RegistrationCollectorPayload() {
        let collector = Fido2RegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        XCTAssertNil(collector.payload())
        
        collector.attestationValue = ["test": "test"]
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?[FidoConstants.FIELD_ATTESTATION_VALUE] as? [String: String], ["test": "test"])
    }
    
    func testFido2RegistrationCollectorRegister() {
        let mockFido2 = MockFido2()
        let collector = Fido2RegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        collector.fido2 = mockFido2
        
        // Test success
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]
        mockFido2.registrationResult = .success(successResponse)
        
        let expectation = self.expectation(description: "FIDO2 registration success")
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
        mockFido2.registrationResult = .failure(FidoError.invalidChallenge)
        let failureExpectation = self.expectation(description: "FIDO2 registration failure")
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
