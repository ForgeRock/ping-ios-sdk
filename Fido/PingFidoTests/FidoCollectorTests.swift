//
//  FidoCollectorTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
import AuthenticationServices
@testable import PingFido
@testable import PingDavinci
@testable import PingDavinciPlugin
internal import PingCommons

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
            XCTAssertEqual(resultAssertionValue[FidoConstants.FIELD_ID] as? String, "rawId".data(using: .utf8)!.base64URLEncodedString())
            
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
    
    // MARK: - Error Propagation Tests

    func testHandleErrorSetsDOMExceptionNameForFidoErrors() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])

        let cases: [(FidoError, String)] = [
            (.timeout, FidoConstants.ERROR_TIMEOUT),
            (.unsupportedAction("msg"), FidoConstants.ERROR_NOT_SUPPORTED),
            (.invalidResponse, FidoConstants.ERROR_INVALID_STATE),
            (.invalidChallenge, FidoConstants.ERROR_INVALID_STATE),
            (.invalidWindow, FidoConstants.ERROR_UNKNOWN),
            (.invalidAction, FidoConstants.ERROR_NOT_SUPPORTED),
            (.missingParameters("msg"), FidoConstants.ERROR_NOT_SUPPORTED),
        ]

        for (fidoError, expectedCode) in cases {
            collector.errorCode = nil
            _ = collector.handleError(error: fidoError)
            XCTAssertEqual(collector.errorCode, expectedCode, "Expected errorCode \(expectedCode) for \(fidoError)")
        }
    }

    func testHandleErrorSetsDOMExceptionNameForASAuthorizationErrors() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])

        let cases: [(Int, String)] = [
            (ASAuthorizationError.canceled.rawValue, FidoConstants.ERROR_NOT_ALLOWED),
            (ASAuthorizationError.failed.rawValue, FidoConstants.ERROR_NOT_ALLOWED),
            (ASAuthorizationError.invalidResponse.rawValue, FidoConstants.ERROR_INVALID_STATE),
            (ASAuthorizationError.notHandled.rawValue, FidoConstants.ERROR_NOT_SUPPORTED),
            (ASAuthorizationError.unknown.rawValue, FidoConstants.ERROR_UNKNOWN),
        ]

        for (code, expectedCode) in cases {
            collector.errorCode = nil
            let nsError = NSError(domain: ASAuthorizationError.errorDomain, code: code, userInfo: nil)
            _ = collector.handleError(error: nsError)
            XCTAssertEqual(collector.errorCode, expectedCode, "Expected errorCode \(expectedCode) for ASAuthorizationError code \(code)")
        }
    }

    func testEventTypeIsSubmitByDefault() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertEqual(collector.eventType(), FidoConstants.EVENT_TYPE_SUBMIT)
    }

    func testEventTypeIsActionAfterError() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        collector.errorCode = FidoConstants.ERROR_NOT_ALLOWED
        XCTAssertEqual(collector.eventType(), FidoConstants.EVENT_TYPE_ACTION)
    }

    func testPayloadIsNonNilAfterError() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertNil(collector.payload())

        collector.errorCode = FidoConstants.ERROR_NOT_ALLOWED
        let payload = collector.payload()
        XCTAssertNotNil(payload)
        XCTAssertTrue(payload?.isEmpty == true, "Error-path payload must be empty dict so formData stays empty")
    }

    func testActionKeyMatchesErrorCode() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertNil(collector.actionKey)

        collector.errorCode = FidoConstants.ERROR_NOT_ALLOWED
        XCTAssertEqual(collector.actionKey, FidoConstants.ERROR_NOT_ALLOWED)
    }

    func testAsJsonContainsActionKeyOnAuthenticationError() {
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        _ = collector.handleError(error: NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue, userInfo: nil))

        let collectors: Collectors = [collector]
        let json = collectors.asJson()

        XCTAssertEqual(json["actionKey"] as? String, FidoConstants.ERROR_NOT_ALLOWED)
        XCTAssertTrue((json["formData"] as? [String: Any])?.isEmpty == true)
    }

    func testAsJsonContainsActionKeyOnRegistrationError() {
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        _ = collector.handleError(error: FidoError.timeout)

        let collectors: Collectors = [collector]
        let json = collectors.asJson()

        XCTAssertEqual(json["actionKey"] as? String, FidoConstants.ERROR_TIMEOUT)
        XCTAssertTrue((json["formData"] as? [String: Any])?.isEmpty == true)
    }

    @MainActor
    func testFidoAuthenticationCollectorForwardsPreferImmediatelyAvailableCredentials() async {
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_AUTHENTICATOR_DATA: "authenticatorData".data(using: .utf8)!,
            FidoConstants.FIELD_SIGNATURE: "signature".data(using: .utf8)!,
            FidoConstants.FIELD_USER_HANDLE: "userHandle".data(using: .utf8)!
        ]

        // Defaults to false, preserving the existing full sign-in behavior (backwards compatible).
        let defaultMock = MockFido()
        defaultMock.authenticationResult = .success(successResponse)
        let defaultCollector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        defaultCollector.fido = defaultMock
        _ = await defaultCollector.authenticate(window: MockASPresentationAnchor())
        XCTAssertEqual(defaultMock.capturedPreferImmediatelyAvailableCredentials, false)

        // Explicitly requesting local-only credentials is forwarded to the underlying Fido manager.
        let preferMock = MockFido()
        preferMock.authenticationResult = .success(successResponse)
        let preferCollector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        preferCollector.fido = preferMock
        _ = await preferCollector.authenticate(window: MockASPresentationAnchor(), preferImmediatelyAvailableCredentials: true)
        XCTAssertEqual(preferMock.capturedPreferImmediatelyAvailableCredentials, true)
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
            XCTAssertEqual(resultAttestationValue[FidoConstants.FIELD_ID] as? String, "rawId".data(using: .utf8)!.base64URLEncodedString())
            
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

    // MARK: - Trigger Tests

    func testTriggerIsParsedFromJson() {
        let registrationJson: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
            FidoConstants.FIELD_TRIGGER: "BUTTON"
        ]
        let registrationCollector = FidoRegistrationCollector(with: registrationJson)
        XCTAssertEqual(registrationCollector.trigger, "BUTTON")

        let authenticationJson: [String: Any] = [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
            FidoConstants.FIELD_TRIGGER: "BUTTON"
        ]
        let authenticationCollector = FidoAuthenticationCollector(with: authenticationJson)
        XCTAssertEqual(authenticationCollector.trigger, "BUTTON")
    }

    func testTriggerDefaultsToEmptyWhenAbsent() {
        let registrationCollector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        XCTAssertEqual(registrationCollector.trigger, "")

        let authenticationCollector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertEqual(authenticationCollector.trigger, "")
    }

    func testIsAutomaticIsFalseForButtonTrigger() {
        let registrationCollector = FidoRegistrationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
            FidoConstants.FIELD_TRIGGER: "BUTTON"
        ])
        XCTAssertFalse(registrationCollector.isAutomatic)

        let authenticationCollector = FidoAuthenticationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
            FidoConstants.FIELD_TRIGGER: "BUTTON"
        ])
        XCTAssertFalse(authenticationCollector.isAutomatic)
    }

    func testIsAutomaticIsFalseWhenTriggerAbsent() {
        let registrationCollector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        XCTAssertFalse(registrationCollector.isAutomatic)

        let authenticationCollector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        XCTAssertFalse(authenticationCollector.isAutomatic)
    }

    func testIsAutomaticIsTrueForNonButtonTrigger() {
        for token in ["AUTOMATIC", "AUTOMATICALLY", "Automatic"] {
            let registrationCollector = FidoRegistrationCollector(with: [
                FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
                FidoConstants.FIELD_TRIGGER: token
            ])
            XCTAssertTrue(registrationCollector.isAutomatic, "Expected isAutomatic to be true for trigger \(token)")

            let authenticationCollector = FidoAuthenticationCollector(with: [
                FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
                FidoConstants.FIELD_TRIGGER: token
            ])
            XCTAssertTrue(authenticationCollector.isAutomatic, "Expected isAutomatic to be true for trigger \(token)")
        }
    }

    func testIsAutomaticIsCaseInsensitiveForButton() {
        for token in ["BUTTON", "button", "Button", "bUtToN"] {
            let registrationCollector = FidoRegistrationCollector(with: [
                FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
                FidoConstants.FIELD_TRIGGER: token
            ])
            XCTAssertFalse(registrationCollector.isAutomatic, "Expected isAutomatic to be false for trigger \(token)")

            let authenticationCollector = FidoAuthenticationCollector(with: [
                FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
                FidoConstants.FIELD_TRIGGER: token
            ])
            XCTAssertFalse(authenticationCollector.isAutomatic, "Expected isAutomatic to be false for trigger \(token)")
        }
    }

    func testTriggerSurvivesGetCollectorFactory() {
        let registrationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_REGISTER,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
            FidoConstants.FIELD_TRIGGER: "AUTOMATIC"
        ]
        let registrationCollector = try? AbstractFidoCollector.getCollector(with: registrationJson)
        XCTAssertEqual(registrationCollector?.trigger, "AUTOMATIC")
        XCTAssertEqual(registrationCollector?.isAutomatic, true)

        let authenticationJson: [String: Any] = [
            FidoConstants.FIELD_ACTION: FidoConstants.ACTION_AUTHENTICATE,
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
            FidoConstants.FIELD_TRIGGER: "BUTTON"
        ]
        let authenticationCollector = try? AbstractFidoCollector.getCollector(with: authenticationJson)
        XCTAssertEqual(authenticationCollector?.trigger, "BUTTON")
        XCTAssertEqual(authenticationCollector?.isAutomatic, false)
    }

    func testNonStringTriggerFallsBackToEmpty() {
        let registrationCollector = FidoRegistrationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]],
            FidoConstants.FIELD_TRIGGER: 42
        ])
        XCTAssertEqual(registrationCollector.trigger, "")
        XCTAssertFalse(registrationCollector.isAutomatic)

        let authenticationCollector = FidoAuthenticationCollector(with: [
            FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"],
            FidoConstants.FIELD_TRIGGER: 42
        ])
        XCTAssertEqual(authenticationCollector.trigger, "")
        XCTAssertFalse(authenticationCollector.isAutomatic)
    }
}
