//
//  PingFidoTests.swift
//  PingFidoTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
                
                // Accept multiple valid failure scenarios on different devices
                let errorMessage = error.localizedDescription
                let validErrors = [
                    "not associated with domain example.com",
                    "Cannot perform passkey request because neither passcode nor biometrics are set up",
                    "NotAllowedError",
                    "InvalidStateError",
                    "NotSupportedError"
                ]
                
                let isValidError = validErrors.contains { validError in
                    errorMessage.contains(validError)
                }
                
                XCTAssertTrue(
                    isValidError,
                    "Expected one of \(validErrors), but got: \(errorMessage)"
                )
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
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
                
                // Accept multiple valid failure scenarios on different devices
                let errorMessage = error.localizedDescription
                let validErrors = [
                    "not associated with domain example.com",
                    "Cannot perform passkey request because neither passcode nor biometrics are set up",
                    "NotAllowedError",
                    "InvalidStateError",
                    "NotSupportedError"
                ]
                
                let isValidError = validErrors.contains { validError in
                    errorMessage.contains(validError)
                }
                
                XCTAssertTrue(
                    isValidError,
                    "Expected one of \(validErrors), but got: \(errorMessage)"
                )
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    @MainActor func testPlatformRegistrationRequestCarriesDisplayName() {
        // Arrange — build a minimal platform-only creation options dict.
        // authenticatorAttachment: "platform" forces only the platform (passkey) request path.
        let displayName = "Jane Doe"
        let userName   = "janedoe"
        let options: [String: Any] = [
            "rp": ["id": "example.com", "name": "Example Corp"],
            "user": ["id": "testuser", "name": userName, "displayName": displayName],
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "pubKeyCredParams": [["type": "public-key", "alg": -7]],
            "authenticatorSelection": ["authenticatorAttachment": "platform"]
        ]

        // Capture the request before performRequests() reaches the system.
        var capturedRequest: ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest?
        fido.testRequestCapture = { request in
            capturedRequest = request as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest
        }

        let window = UIWindow()
        fido.register(options: options, window: window) { _ in }

        XCTAssertNotNil(capturedRequest, "Platform registration request was not created")
        XCTAssertEqual(capturedRequest?.displayName, displayName)
        // When displayName is present, createPlatformRequest passes it as the `name` argument
        // to createCredentialRegistrationRequest — this is the value shown in the system sheet.
        XCTAssertEqual(capturedRequest?.name, displayName)
    }

    @MainActor func testAuthenticatePreferImmediatelyAvailableCredentialsExcludesSecurityKeyRequest() {
        // With allowCredentials present, the default (false) ceremony builds a platform request
        // plus a security-key request. Setting preferImmediatelyAvailableCredentials to true must
        // suppress the security-key request, since a hardware key can never be "immediately available".
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com",
            "allowCredentials": [
                ["type": "public-key", "id": "Y3JlZGVudGlhbElk"]
            ]
        ]

        var capturedRequests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { request in
            capturedRequests.append(request)
        }

        let window = UIWindow()
        fido.authenticate(options: options, window: window, preferImmediatelyAvailableCredentials: true) { _ in }

        XCTAssertEqual(capturedRequests.count, 1, "Only the platform request should be built when preferring immediately available credentials")
        XCTAssertTrue(capturedRequests.first is ASAuthorizationPlatformPublicKeyCredentialAssertionRequest)
        XCTAssertFalse(capturedRequests.contains { $0 is ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest })
    }

    @MainActor func testAuthenticateDefaultIncludesSecurityKeyRequestWhenAllowCredentialsPresent() {
        // Existing (default) behavior: allowCredentials present builds both a platform request
        // and a security-key request. This must be unaffected by the new option's default value.
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com",
            "allowCredentials": [
                ["type": "public-key", "id": "Y3JlZGVudGlhbElk"]
            ]
        ]

        var capturedRequests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { request in
            capturedRequests.append(request)
        }

        let window = UIWindow()
        fido.authenticate(options: options, window: window) { _ in }

        XCTAssertEqual(capturedRequests.count, 2, "Both platform and security-key requests should be built by default")
        XCTAssertTrue(capturedRequests.contains { $0 is ASAuthorizationPlatformPublicKeyCredentialAssertionRequest })
        XCTAssertTrue(capturedRequests.contains { $0 is ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest })
    }

    @MainActor func testAuthenticateWithAutoFillBuildsExactlyOnePlatformRequest() {
        // performAutoFillAssistedRequests() requires exactly one platform assertion request —
        // no security-key branch, unlike authenticate(), even when allowCredentials is present.
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com",
            "allowCredentials": [
                ["type": "public-key", "id": "Y3JlZGVudGlhbElk"]
            ]
        ]

        var capturedRequests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { request in
            capturedRequests.append(request)
        }

        let window = UIWindow()
        fido.authenticateWithAutoFill(options: options, window: window) { _ in }

        XCTAssertEqual(capturedRequests.count, 1, "Only a single platform request should be built for autofill-assisted authentication")
        XCTAssertTrue(capturedRequests.first is ASAuthorizationPlatformPublicKeyCredentialAssertionRequest)
    }

    @MainActor func testAuthenticateWithAutoFillDoesNotScheduleTimeout() {
        // Unlike authenticate()/register(), the autofill-assisted ceremony is meant to stay
        // active for the lifetime of the field, not a fixed duration.
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com",
            "timeout": 60000
        ]

        let window = UIWindow()
        fido.authenticateWithAutoFill(options: options, window: window) { _ in }

        XCTAssertNil(fido.timeoutTask, "authenticateWithAutoFill must not schedule a timeout task")
    }

    @MainActor func testCancelWithNoInFlightCeremonyIsNoOp() {
        fido.cancel()

        XCTAssertNil(fido.authorizationController)
        XCTAssertNil(fido.completion)
    }

    @MainActor func testCancelCompletesInFlightCeremonySynchronouslyWithFidoErrorCanceled() {
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com"
        ]
        var capturedResult: Result<[String: Any], Error>?
        let window = UIWindow()
        fido.authenticate(options: options, window: window) { result in
            capturedResult = result
        }
        XCTAssertNotNil(fido.authorizationController, "Ceremony should be in flight before cancel")

        fido.cancel()

        guard case .failure(let error) = capturedResult else {
            XCTFail("Expected cancel() to synchronously complete the in-flight ceremony with a failure")
            return
        }
        XCTAssertEqual(error as? FidoError, .canceled)
        XCTAssertNil(fido.authorizationController)
        XCTAssertNil(fido.window)
    }

    @MainActor func testNewCeremonySupersedesInFlightAutoFillListener() {
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com"
        ]
        var autoFillResult: Result<[String: Any], Error>?
        let window = UIWindow()
        fido.authenticateWithAutoFill(options: options, window: window) { result in
            autoFillResult = result
        }
        let autoFillController = fido.authorizationController
        XCTAssertNotNil(autoFillController)

        var capturedRequests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { request in capturedRequests.append(request) }

        fido.authenticate(options: options, window: window) { _ in }

        guard case .failure(let error) = autoFillResult else {
            XCTFail("Expected the superseded autofill listener to fail with .canceled")
            return
        }
        XCTAssertEqual(error as? FidoError, .canceled)
        XCTAssertEqual(capturedRequests.count, 1, "The new authenticate() ceremony's request should have been captured")
        XCTAssertFalse(fido.authorizationController === autoFillController, "A new controller should have replaced the superseded one")
    }

    @MainActor func testStaleDelegateCallbackAfterSupersessionIsIgnored() {
        let options: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com"
        ]
        var firstResult: Result<[String: Any], Error>?
        var secondResult: Result<[String: Any], Error>?
        let window = UIWindow()

        fido.authenticateWithAutoFill(options: options, window: window) { result in
            firstResult = result
        }
        let staleController = fido.authorizationController!

        fido.authenticate(options: options, window: window) { result in
            secondResult = result
        }
        // The synchronous supersede already resolved firstResult with .canceled at this point.
        XCTAssertNotNil(firstResult)

        // Simulate a late delegate callback arriving from the now-superseded controller.
        let staleError = NSError(domain: ASAuthorizationError.errorDomain, code: ASAuthorizationError.canceled.rawValue, userInfo: nil)
        fido.authorizationController(controller: staleController, didCompleteWithError: staleError)

        XCTAssertNil(secondResult, "The stale callback must not touch the new ceremony's completion")
        XCTAssertNotNil(fido.authorizationController, "The new ceremony's state must remain intact")
    }

    @MainActor func testRegisterSupersedesInFlightAutoFillListener() {
        // register() also calls supersedeInFlightCeremony() at its start; this pins that a
        // ceremony other than authenticate()/authenticateWithAutoFill can be the "new" one too.
        let authOptions: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com"
        ]
        var autoFillResult: Result<[String: Any], Error>?
        let window = UIWindow()
        fido.authenticateWithAutoFill(options: authOptions, window: window) { result in
            autoFillResult = result
        }
        XCTAssertNotNil(fido.authorizationController)

        let registrationOptions: [String: Any] = [
            "rp": ["id": "example.com", "name": "Example Corp"],
            "user": ["id": "testuser", "name": "testuser", "displayName": "Test User"],
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "pubKeyCredParams": [["type": "public-key", "alg": -7]]
        ]
        var capturedRequests: [ASAuthorizationRequest] = []
        fido.testRequestCapture = { request in capturedRequests.append(request) }

        fido.register(options: registrationOptions, window: window) { _ in }

        guard case .failure(let error) = autoFillResult else {
            XCTFail("Expected the superseded autofill listener to fail with .canceled")
            return
        }
        XCTAssertEqual(error as? FidoError, .canceled)
        XCTAssertFalse(capturedRequests.isEmpty, "register()'s own request(s) should have been captured")
    }

    @MainActor func testStaleTimeoutAfterSupersessionIsIgnored() {
        // The timeout task's `Task.isCancelled` check runs off-actor; it can pass a moment before
        // a supersede lands on the MainActor. fireTimeout(generation:) must re-check the
        // ceremony's identity once actually isolated, so a stale timeout from a since-superseded
        // ceremony can't complete (or clean up the state of) whatever ceremony is current by then.
        let optionsWithTimeout: [String: Any] = [
            "challenge": "IrmRP2U3shw3plwrICzAkw/yupRI60s2dnGhfwExd/o=",
            "rpId": "example.com",
            "timeout": 60000
        ]
        var firstResult: Result<[String: Any], Error>?
        var secondResult: Result<[String: Any], Error>?
        let window = UIWindow()

        fido.authenticate(options: optionsWithTimeout, window: window) { result in
            firstResult = result
        }
        XCTAssertNotNil(fido.timeoutTask, "A timeout task should have been scheduled")
        let staleGeneration = fido.ceremonyGeneration

        // Supersede with a fresh ceremony before the original timeout fires.
        fido.authenticate(options: optionsWithTimeout, window: window) { result in
            secondResult = result
        }
        XCTAssertNotNil(firstResult, "The first ceremony should have been synchronously superseded")

        // Simulate the original timeout task finally reaching its MainActor body late, using the
        // generation it captured before it was superseded.
        fido.fireTimeout(generation: staleGeneration)

        XCTAssertNil(secondResult, "The stale timeout must not touch the new ceremony's completion")
        XCTAssertNotNil(fido.authorizationController, "The new ceremony's state must remain intact")
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

    func testHandleErrorMapsFidoErrorCanceledToNotAllowedError() {
        // Mirrors AbstractFidoCollector's handling of the same enum case (DaVinci side) — a
        // superseded/explicitly-cancelled ceremony must map to the same NotAllowedError outcome
        // as a native ASAuthorizationError.canceled, not fall through to a generic UnknownError.
        let callback = FidoCallback()
        let journey = Journey.createJourney()
        let hiddenValueCallback = HiddenValueCallback()
        hiddenValueCallback.initValue(name: JourneyConstants.id, value: FidoConstants.WEB_AUTHN_OUTCOME)
        let continueNode = MockContinueNode(callbacks: Callbacks([hiddenValueCallback]))
        callback.journey = journey
        callback.continueNode = continueNode

        callback.handleError(error: FidoError.canceled)

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
