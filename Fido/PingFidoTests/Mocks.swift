import Foundation
import AuthenticationServices
@testable import PingFido
@testable import PingJourney
@testable import PingOrchestrate

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

class MockFido: Fido {
    var registrationResult: Result<[String: Any], Error>?
    var authenticationResult: Result<[String: Any], Error>?
    
    override func register(options: [String : Any], window: ASPresentationAnchor, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        if let result = registrationResult {
            completion(result)
        }
    }
    
    override func authenticate(options: [String : Any], window: ASPresentationAnchor, completion: @escaping (Result<[String : Any], Error>) -> Void) {
        if let result = authenticationResult {
            completion(result)
        }
    }
}

class MockASPresentationAnchor: UIWindow {
    
}
