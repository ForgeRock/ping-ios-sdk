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

    override func register(options: [String : Any], window: ASPresentationAnchor, logger: Logger? = nil, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        capturedLogger = logger
        if let result = registrationResult {
            completion(result)
        }
    }

    override func authenticate(options: [String : Any], window: ASPresentationAnchor, logger: Logger? = nil, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        capturedLogger = logger
        if let result = authenticationResult {
            completion(result)
        }
    }
}

class MockASPresentationAnchor: UIWindow {
    
}
