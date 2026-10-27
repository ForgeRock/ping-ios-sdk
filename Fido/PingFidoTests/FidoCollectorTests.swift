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
            XCTAssertEqual(resultAssertionValue[FidoConstants.FIELD_RAW_ID] as? String, "rawId".data(using: .utf8)!.base64URLEncodedString())
            let responseObject = resultAssertionValue[FidoConstants.FIELD_RESPONSE] as? [String: Any]
            XCTAssertEqual(responseObject?[FidoConstants.FIELD_USER_HANDLE] as? String, "userHandle".data(using: .utf8)!.base64URLEncodedString())

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
    
    // MARK: - FidoAuthenticationCollector Payload Shape Tests

    private func assertBase64URLUnpadded(_ value: Any?, equals expected: Data, _ field: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let string = value as? String else {
            XCTFail("Expected \(field) to be a String", file: file, line: line)
            return
        }
        XCTAssertNotNil(string.range(of: "^[A-Za-z0-9_-]*$", options: .regularExpression), "\(field) is not unpadded base64url: \(string)", file: file, line: line)
        XCTAssertEqual(Base64.decodeBase64UrlToData(string), expected, "\(field) does not round-trip", file: file, line: line)
    }

    @MainActor
    private func authenticate(_ response: [String: Any]) async -> (result: Result<[String: Any], Error>, collector: FidoAuthenticationCollector) {
        let mockFido = MockFido()
        let collector = FidoAuthenticationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_REQUEST_OPTIONS: ["challenge": "test"]])
        collector.fido = mockFido
        mockFido.authenticationResult = .success(response)
        let result = await collector.authenticate(window: MockASPresentationAnchor())
        return (result, collector)
    }

    @MainActor
    func testFidoAuthenticationCollectorPayloadFieldsAreBase64URLUnpadded() async {
        let credentialID = Data([0xFB, 0xFF, 0xBF, 0xFE])
        let authenticatorData = Data([0xFF, 0xFB, 0xBF, 0xFE, 0x01])
        let clientData = Data([0xBF, 0xFB, 0xFF])
        let signature = Data([0xFE, 0xFF, 0xFB, 0xBF, 0x02, 0x03])
        let userHandle = Data([0xFB, 0xFF, 0xBF, 0xFE, 0xFF])

        let (result, _) = await authenticate([
            FidoConstants.FIELD_RAW_ID: credentialID,
            FidoConstants.FIELD_CLIENT_DATA_JSON: clientData,
            FidoConstants.FIELD_AUTHENTICATOR_DATA: authenticatorData,
            FidoConstants.FIELD_SIGNATURE: signature,
            FidoConstants.FIELD_USER_HANDLE: userHandle
        ])

        guard case .success(let value) = result else {
            XCTFail("Expected authenticate to succeed")
            return
        }
        let responseObject = value[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        assertBase64URLUnpadded(value[FidoConstants.FIELD_ID], equals: credentialID, "id")
        assertBase64URLUnpadded(value[FidoConstants.FIELD_RAW_ID], equals: credentialID, "rawId")
        assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_AUTHENTICATOR_DATA], equals: authenticatorData, "authenticatorData")
        assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_CLIENT_DATA_JSON], equals: clientData, "clientDataJSON")
        assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_SIGNATURE], equals: signature, "signature")
        assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_USER_HANDLE], equals: userHandle, "userHandle")
        XCTAssertEqual(value[FidoConstants.FIELD_RAW_ID] as? String, value[FidoConstants.FIELD_ID] as? String)
    }

    @MainActor
    func testFidoAuthenticationCollectorEncodesNonUTF8UserHandleAsBase64URL() async {
        let (result, _) = await authenticate([
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
            FidoConstants.FIELD_SIGNATURE: Data([0x04]),
            FidoConstants.FIELD_USER_HANDLE: Data([0xFB, 0xFF, 0xBF])
        ])

        guard case .success(let value) = result else {
            XCTFail("Expected authenticate to succeed")
            return
        }
        let responseObject = value[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        XCTAssertEqual(responseObject?[FidoConstants.FIELD_USER_HANDLE] as? String, "-_-_")
    }

    @MainActor
    func testFidoAuthenticationCollectorPassesThroughAuthenticatorAttachment() async {
        let base: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
            FidoConstants.FIELD_SIGNATURE: Data([0x04]),
            FidoConstants.FIELD_USER_HANDLE: Data([0x05])
        ]

        for attachment in ["platform", "cross-platform"] {
            var response = base
            response[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] = attachment
            let (result, collector) = await authenticate(response)
            guard case .success(let value) = result else {
                XCTFail("Expected authenticate to succeed for \(attachment)")
                continue
            }
            XCTAssertEqual(value[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, attachment)
            XCTAssertEqual(collector.assertionValue?[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, attachment)
        }

        let (result, _) = await authenticate(base)
        guard case .success(let value) = result else {
            XCTFail("Expected authenticate to succeed without an attachment")
            return
        }
        XCTAssertEqual(value[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, "platform")
    }

    @MainActor
    func testFidoAuthenticationCollectorOmitsUserHandleWhenEmpty() async {
        let (result, collector) = await authenticate([
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
            FidoConstants.FIELD_SIGNATURE: Data([0x04]),
            FidoConstants.FIELD_USER_HANDLE: Data()
        ])

        guard case .success(let value) = result else {
            XCTFail("Expected authenticate to succeed with an empty user handle")
            return
        }
        let responseObject = value[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        XCTAssertNotNil(responseObject)
        XCTAssertNil(responseObject?[FidoConstants.FIELD_USER_HANDLE])
        let payloadResponse = (collector.payload()?[FidoConstants.FIELD_ASSERTION_VALUE] as? [String: Any])?[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        XCTAssertNil(payloadResponse?[FidoConstants.FIELD_USER_HANDLE])
    }

    @MainActor
    func testFidoAuthenticationCollectorReturnsRawUserIDBytesAsUserHandle() async {
        // Raw user ID bytes F3 9A 01, as registered for a DaVinci passkey.
        let rawUserID = Data([0xF3, 0x9A, 0x01])
        let (result, collector) = await authenticate([
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
            FidoConstants.FIELD_SIGNATURE: Data([0x04]),
            FidoConstants.FIELD_USER_HANDLE: rawUserID
        ])

        guard case .success = result else {
            XCTFail("Expected authenticate to succeed")
            return
        }
        let responseObject = collector.assertionValue?[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        let userHandle = responseObject?[FidoConstants.FIELD_USER_HANDLE] as? String
        XCTAssertEqual(userHandle, "85oB")
        XCTAssertEqual(Base64.decodeBase64UrlToData(userHandle ?? ""), rawUserID)
    }

    @MainActor
    func testFidoAuthenticationCollectorReportsLegacyTextUserIDBytesAsBase64URL() async {
        // Passkeys created by earlier versions stored the UTF-8 bytes of the text "85oB" (38 35 6F 42).
        let legacyUserID = Data("85oB".utf8)
        XCTAssertEqual(legacyUserID, Data([0x38, 0x35, 0x6F, 0x42]))

        let (result, collector) = await authenticate([
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
            FidoConstants.FIELD_SIGNATURE: Data([0x04]),
            FidoConstants.FIELD_USER_HANDLE: legacyUserID
        ])

        guard case .success = result else {
            XCTFail("Expected authenticate to succeed")
            return
        }
        let responseObject = collector.assertionValue?[FidoConstants.FIELD_RESPONSE] as? [String: Any]
        XCTAssertEqual(responseObject?[FidoConstants.FIELD_USER_HANDLE] as? String, "ODVvQg")
    }

    @MainActor
    func testFidoAuthenticationCollectorEncodesOneByteAndThirtyTwoByteUserHandlesAsUnpaddedBase64URL() async {
        // 32 bytes encode to 43 base64url characters and one byte to 2; both would carry "=" padding in standard base64.
        let thirtyTwoBytes = Data((0..<32).map { UInt8(truncatingIfNeeded: 0xFB &+ $0 &* 7) })
        let handles: [(data: Data, length: Int)] = [(Data([0xFB]), 2), (thirtyTwoBytes, 43)]

        for handle in handles {
            let (result, _) = await authenticate([
                FidoConstants.FIELD_RAW_ID: Data([0x01]),
                FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
                FidoConstants.FIELD_AUTHENTICATOR_DATA: Data([0x03]),
                FidoConstants.FIELD_SIGNATURE: Data([0x04]),
                FidoConstants.FIELD_USER_HANDLE: handle.data
            ])

            guard case .success(let value) = result else {
                XCTFail("Expected authenticate to succeed for a \(handle.data.count)-byte user handle")
                continue
            }
            let responseObject = value[FidoConstants.FIELD_RESPONSE] as? [String: Any]
            assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_USER_HANDLE], equals: handle.data, "userHandle")
            XCTAssertEqual((responseObject?[FidoConstants.FIELD_USER_HANDLE] as? String)?.count, handle.length)
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
    
    @MainActor
    func testFidoRegistrationCollectorAlwaysRequestsBase64UserIDEncoding() async {
        let successResponse: [String: Any] = [
            FidoConstants.FIELD_RAW_ID: "rawId".data(using: .utf8)!,
            FidoConstants.FIELD_CLIENT_DATA_JSON: "clientDataJSON".data(using: .utf8)!,
            FidoConstants.FIELD_ATTESTATION_OBJECT: "attestationObject".data(using: .utf8)!
        ]

        for userID: Any in [[-5, -1, -65], "dGVzdHVzZXI"] {
            let mockFido = MockFido()
            mockFido.registrationResult = .success(successResponse)
            let collector = FidoRegistrationCollector(with: [
                FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: [
                    "rp": ["name": "test"],
                    "user": ["id": userID, "name": "janedoe", "displayName": "Jane Doe"]
                ]
            ])
            collector.fido = mockFido

            _ = await collector.register(window: MockASPresentationAnchor())

            XCTAssertEqual(mockFido.capturedUserIDEncoding, .base64)
            if let stringUserID = userID as? String {
                let capturedUser = mockFido.capturedOptions?["user"] as? [String: Any]
                XCTAssertEqual(capturedUser?["id"] as? String, stringUserID)
            }
        }
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

    @MainActor
    func testFidoRegistrationCollectorPayloadFieldsAreBase64URLUnpadded() async {
        let credentialID = Data([0xFB, 0xFF, 0xBF, 0xFE])
        let clientData = Data([0xBF, 0xFB, 0xFF])
        let attestationObject = Data([0xFF, 0xFB, 0xBF, 0xFE, 0x01])

        for attachment in ["platform", "cross-platform"] {
            let mockFido = MockFido()
            let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
            collector.fido = mockFido
            mockFido.registrationResult = .success([
                FidoConstants.FIELD_RAW_ID: credentialID,
                FidoConstants.FIELD_CLIENT_DATA_JSON: clientData,
                FidoConstants.FIELD_ATTESTATION_OBJECT: attestationObject,
                FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT: attachment
            ])

            let result = await collector.register(window: MockASPresentationAnchor())

            guard case .success(let value) = result else {
                XCTFail("Expected register to succeed for \(attachment)")
                continue
            }
            let responseObject = value[FidoConstants.FIELD_RESPONSE] as? [String: Any]
            assertBase64URLUnpadded(value[FidoConstants.FIELD_ID], equals: credentialID, "id")
            assertBase64URLUnpadded(value[FidoConstants.FIELD_RAW_ID], equals: credentialID, "rawId")
            assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_CLIENT_DATA_JSON], equals: clientData, "clientDataJSON")
            assertBase64URLUnpadded(responseObject?[FidoConstants.FIELD_ATTESTATION_OBJECT], equals: attestationObject, "attestationObject")
            XCTAssertEqual(value[FidoConstants.FIELD_RAW_ID] as? String, value[FidoConstants.FIELD_ID] as? String)
            XCTAssertEqual(value[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, attachment)
            XCTAssertEqual(collector.attestationValue?[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, attachment)
        }
    }

    @MainActor
    func testFidoRegistrationCollectorReportsPlatformAttachmentWhenResponseHasNone() async {
        let mockFido = MockFido()
        let collector = FidoRegistrationCollector(with: [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: ["rp": ["name": "test"]]])
        collector.fido = mockFido
        mockFido.registrationResult = .success([
            FidoConstants.FIELD_RAW_ID: Data([0x01]),
            FidoConstants.FIELD_CLIENT_DATA_JSON: Data([0x02]),
            FidoConstants.FIELD_ATTESTATION_OBJECT: Data([0x03])
        ])

        let result = await collector.register(window: MockASPresentationAnchor())

        guard case .success(let value) = result else {
            XCTFail("Expected register to succeed")
            return
        }
        XCTAssertEqual(value[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, "platform")
        XCTAssertEqual(collector.attestationValue?[FidoConstants.FIELD_AUTHENTICATOR_ATTACHMENT] as? String, "platform")
    }

    // MARK: - Registration User ID Composition Tests

    private func davinciRegistrationJson(userID: [Int], attachment: String? = nil) -> [String: Any] {
        var options: [String: Any] = [
            "rp": ["id": "example.com", "name": "Example Corp"],
            "user": ["id": userID, "name": "janedoe", "displayName": "Jane Doe"],
            "challenge": [1, 2, 3, 4],
            "pubKeyCredParams": [["type": "public-key", "alg": -7]]
        ]
        if let attachment {
            options["authenticatorSelection"] = ["authenticatorAttachment": attachment]
        }
        return [FidoConstants.FIELD_PUBLIC_KEY_CREDENTIAL_CREATION_OPTIONS: options]
    }

    /// Runs `register(window:)` against a real `Fido` without system UI and returns the captured requests.
    /// The pending ceremony is completed from the capture hook so that `register(window:)` returns.
    @MainActor
    private func registerWithRealFido(_ json: [String: Any]) async -> (requests: [ASAuthorizationRequest], result: Result<[String: Any], Error>) {
        let fido = NoUIFido()
        let collector = FidoRegistrationCollector(with: json)
        collector.fido = fido

        var requests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { [unowned fido] request in
            requests.append(request)
            let completion = fido.completion
            fido.completion = nil
            completion?(.failure(FidoError.timeout))
        }

        let result = await collector.register(window: MockASPresentationAnchor())
        return (requests, result)
    }

    @MainActor
    func testRegistrationCollectorToFidoRegistersSignedByteUserIDAsRawBytesOnPlatformRequest() async {
        // Signed values -13, -102, 1 are the bytes F3 9A 01.
        let (requests, _) = await registerWithRealFido(davinciRegistrationJson(userID: [-13, -102, 1], attachment: "platform"))

        XCTAssertEqual(requests.count, 1)
        let request = requests.first as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest
        XCTAssertNotNil(request, "Platform registration request was not created")
        XCTAssertEqual(request?.userID, Data([0xF3, 0x9A, 0x01]))
    }

    @MainActor
    func testRegistrationCollectorToFidoRegistersSignedByteUserIDAsRawBytesOnSecurityKeyRequest() async {
        let (requests, _) = await registerWithRealFido(davinciRegistrationJson(userID: [-13, -102, 1], attachment: "cross-platform"))

        XCTAssertEqual(requests.count, 1)
        let request = requests.first as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest
        XCTAssertNotNil(request, "Security key registration request was not created")
        XCTAssertEqual(request?.userID, Data([0xF3, 0x9A, 0x01]))
    }

    @MainActor
    func testRegistrationCollectorToFidoPreservesSignedByteEdgeValues() async {
        let (requests, _) = await registerWithRealFido(davinciRegistrationJson(userID: [-128, 127, 0, -1], attachment: "platform"))

        let request = requests.first as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest
        XCTAssertEqual(request?.userID, Data([0x80, 0x7F, 0x00, 0xFF]))
    }

    @MainActor
    func testRegistrationCollectorToFidoFailsBeforeAnyRequestWhenUserIDIsEmpty() async {
        let (requests, result) = await registerWithRealFido(davinciRegistrationJson(userID: []))

        XCTAssertTrue(requests.isEmpty, "No request should be created for an empty user ID")
        guard case .failure(let error) = result, case FidoError.missingParameters = error else {
            XCTFail("Expected FidoError.missingParameters, got \(result)")
            return
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
