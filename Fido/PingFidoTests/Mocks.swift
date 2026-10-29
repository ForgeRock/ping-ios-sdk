//
//  Mocks.swift
//  PingFidoTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices
@testable import PingFido
@testable import PingJourneyPlugin
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingLogger

class MockASAuthorizationController: ASAuthorizationController {
    var performRequestsCalled = false

    override func performRequests() {
        performRequestsCalled = true
    }

    override func performRequests(options: ASAuthorizationController.RequestOptions) {
        performRequestsCalled = true
    }
}

class MockASAuthorizationPlatformPublicKeyCredentialRegistration: ASAuthorizationPlatformPublicKeyCredentialRegistration, @unchecked Sendable {
    override var rawAttestationObject: Data? {
        return "attestationObject".data(using: .utf8)
    }
    
    override var rawClientDataJSON: Data {
        return "clientDataJSON".data(using: .utf8)!
    }
    
    override var credentialID: Data {
        return "credentialID".data(using: .utf8)!
    }
}

class MockASAuthorizationPlatformPublicKeyCredentialAssertion: ASAuthorizationPlatformPublicKeyCredentialAssertion, @unchecked Sendable {
    override var rawAuthenticatorData: Data {
        return "authenticatorData".data(using: .utf8)!
    }
    
    override var rawClientDataJSON: Data {
        return "clientDataJSON".data(using: .utf8)!
    }
    
    override var signature: Data {
        return "signature".data(using: .utf8)!
    }
    
    override var credentialID: Data {
        return "credentialID".data(using: .utf8)!
    }
    
    override var userID: Data {
        return "userID".data(using: .utf8)!
    }
}

class MockContinueNode: ContinueNode, @unchecked Sendable {
    
    init(callbacks: Callbacks) {
        let journey = Journey.createJourney()
        super.init(context: FlowContext(flowContext: SharedContext()), workflow: journey, input: [:], actions: callbacks)
    }
}

class MockFido: Fido, @unchecked Sendable {
    var registrationResult: Result<[String: Any], Error>?
    var authenticationResult: Result<[String: Any], Error>?
    /// Captures the `logger` parameter passed to the most recent call to `register` or
    /// `authenticate`, so tests can assert callers propagate the workflow logger.
    var capturedLogger: Logger?
    /// Captures the `preferImmediatelyAvailableCredentials` flag passed to the most recent
    /// call to `authenticate`, so tests can assert callers forward it.
    var capturedPreferImmediatelyAvailableCredentials: Bool?
    /// Captures the `userIDEncoding` passed to the most recent call to `register`.
    var capturedUserIDEncoding: FidoUserIDEncoding?
    /// Captures the `options` passed to the most recent call to `register`.
    var capturedOptions: [String: Any]?

    override func register(options: [String : Any], window: ASPresentationAnchor, userIDEncoding: FidoUserIDEncoding = .utf8, logger: Logger? = nil, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        capturedLogger = logger
        capturedUserIDEncoding = userIDEncoding
        capturedOptions = options
        if let result = registrationResult {
            completion(result)
        }
    }

    override func authenticate(options: [String : Any], window: ASPresentationAnchor, preferImmediatelyAvailableCredentials: Bool = false, logger: Logger? = nil, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        capturedLogger = logger
        capturedPreferImmediatelyAvailableCredentials = preferImmediatelyAvailableCredentials
        if let result = authenticationResult {
            completion(result)
        }
    }
}

/// A real `Fido` whose authorization controller never presents system UI, so the unmodified
/// `register` and `authenticate` logic runs and its requests can be observed through `testRequestCapture`.
class NoUIFido: Fido, @unchecked Sendable {
    override func makeAuthorizationController(requests: [ASAuthorizationRequest]) -> ASAuthorizationController {
        requests.forEach { testRequestCapture?($0) }
        let controller = MockASAuthorizationController(authorizationRequests: requests)
        authorizationController = controller
        return controller
    }
}

class MockASPresentationAnchor: UIWindow {
    
}
