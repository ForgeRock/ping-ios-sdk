// 
//  SIWAHelpers.swift
//  ExternalIdPApple
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import AuthenticationServices
import PingExternalIdP

/// Represents the result of a Sign In With Apple request.
struct SignInWithAppleResult: Sendable {
    /// The AICAppleSignInResponse object to be used for AIC directly. Contains code, id_token, state, and user information.
    let appleSignInResponse: AppleSignInResponse
    /// The nickName returned by Apple.
    let nickName: String?
    /// The nonce returned by Apple.
    let nonce: String?
    
    /// Full name computed property, combining first and last name.
    var fullName: String? {
        if let firstName = appleSignInResponse.user.name?.firstName, let lastName = appleSignInResponse.user.name?.lastName {
            return firstName + " " + lastName
        } else if let firstName = appleSignInResponse.user.name?.firstName {
            return firstName
        } else if let lastName = appleSignInResponse.user.name?.lastName {
            return lastName
        }
        return nil
    }
    
    /// Display name computed property, using fullName if available, otherwise nickName
    var displayName: String? {
        fullName ?? nickName
    }
    
    /// Initialize a new `SignInWithAppleResult` object.
    /// - Parameters:
    ///  - authorization : The authorization object returned by Apple.
    ///  - nonce : The nonce used for the request.
    ///  - Returns: A new `SignInWithAppleResult` object, or nil if the authorization object
    init?(authorization: ASAuthorization, nonce: String) {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
        else {
            return nil
        }
        
        self.nickName = appleIDCredential.fullName?.nickname
        self.nonce = nonce
        self.appleSignInResponse = AppleSignInResponse(appleIDCredential)
    }
}

/// Helper class to handle Sign In With Apple requests.
@MainActor
final class SignInWithAppleHelper: NSObject {
    
    /// The IdpClient used for the request.
    let idpClient: IdpClient
    /// The completion handler for the request
    private var completionHandler: ((Result<SignInWithAppleResult, Error>) -> Void)? = nil
    /// The current nonce for the request.
    private var currentNonce: String? = nil
    
    /// Initialize a new `SignInWithAppleHelper` object.
    /// - Parameters:
    ///  - idpClient: The IdpClient used for the request.
    ///  - Returns: A new `SignInWithAppleHelper` object.
    init(idpClient: IdpClient) {
        self.idpClient = idpClient
        self.currentNonce = idpClient.nonce
    }
    
    /// Start Sign In With Apple and present OS modal.
    /// - Parameter viewController: ViewController to present OS modal on. If nil, function will attempt to find the top-most ViewController. Throws an error if no ViewController is found.
    /// - Returns: A stream of `SignInWithAppleResult` objects.
    func startSignInWithAppleFlow(viewController: UIViewController? = nil) -> AsyncThrowingStream<SignInWithAppleResult, Error> {
        var requestedScopes: [ASAuthorization.Scope] = []
        for scope in idpClient.scopes {
            if (scope == "name" || scope == "fullName") {
                requestedScopes.append(.fullName)
            }
            if (scope == "email") {
                requestedScopes.append(.email)
            }
        }
        return AsyncThrowingStream { continuation in
            startSignInWithAppleFlow(nonce: idpClient.nonce, scopes: requestedScopes) { result in
                switch result {
                case .success(let signInWithAppleResult):
                    continuation.yield(signInWithAppleResult)
                    continuation.finish()
                    return
                case .failure(let error):
                    continuation.finish(throwing: error)
                    return
                }
            }
        }
    }
    
    /// Start Sign In With Apple and present OS modal.
    /// - Parameter nonce: The nonce to use for the request.
    /// - Parameter scopes: The scopes to request from Apple.
    /// - Parameter viewController: ViewController to present OS modal on. If nil, function will attempt to find the top-most ViewController. Throws an error if no ViewController is found.
    /// - Parameter completion: The completion handler for the request.
    private func startSignInWithAppleFlow(nonce: String?, scopes: [ASAuthorization.Scope], viewController: UIViewController? = nil, completion: @escaping (Result<SignInWithAppleResult, Error>) -> Void) {
        guard let topVC = IdpClient.getTopViewController() else {
            completion(.failure(SignInWithAppleError.noViewController))
            return
        }
        currentNonce = nonce
        completionHandler = completion
        showOSPrompt(nonce: nonce, scopes: scopes, on: topVC)
    }
    
}

// MARK: PRIVATE
private extension SignInWithAppleHelper {
    /// Show the OS prompt for Sign In With Apple.
    private func showOSPrompt(nonce: String?, scopes: [ASAuthorization.Scope], on viewController: UIViewController) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = scopes
        request.nonce = nonce
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = viewController
        
        authorizationController.performRequests()
    }
    
    /// SignInWithAppleError enum.
    /// - noViewController: Could not find top view controller.
    /// - invalidCredential: Invalid sign in credential.
    /// - badResponse: Apple Sign In had a bad response.
    /// - unableToFindNonce: Apple Sign In token
    private enum SignInWithAppleError: LocalizedError, Sendable {
        case noViewController
        case invalidCredential
        case badResponse
        case unableToFindNonce
        
        var errorDescription: String? {
            switch self {
            case .noViewController:
                return "Could not find top view controller."
            case .invalidCredential:
                return "Invalid sign in credential."
            case .badResponse:
                return "Apple Sign In had a bad response."
            case .unableToFindNonce:
                return "Apple Sign In token expired."
            }
        }
    }
}

struct AppleSignInResponse: Codable {
    var code: String?
    var id_token: String?
    var state: String?
    var user: AppleSignInUser
    
    init(_ appleIDCredential: ASAuthorizationAppleIDCredential) {
        if let code = appleIDCredential.authorizationCode {
            self.code = String(data: code, encoding: .utf8)
        } else {
            self.code = nil
        }
        if let id_token = appleIDCredential.identityToken {
            self.id_token = String(data: id_token, encoding: .utf8)
        } else {
            self.id_token = nil
        }
        self.state = appleIDCredential.state
        self.user = AppleSignInUser(nameComponents: appleIDCredential.fullName, email: appleIDCredential.email)
    }
}

struct AppleSignInUser: Codable {
    var name: FullName?
    var email: String
    
    init(nameComponents: PersonNameComponents?, email: String?) {
        if let nameComponents = nameComponents {
            self.name = FullName(nameComponents)
        } else {
            self.name = nil
        }
        self.email = email ?? ""
    }
}

struct FullName: Codable {
    var firstName: String?
    var lastName: String?
}

extension FullName {
    init(_ nameComponents: PersonNameComponents) {
        firstName = nameComponents.givenName
        lastName = nameComponents.familyName
    }
}

//MARK: ASAuthorizationControllerDelegate
extension SignInWithAppleHelper: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        do {
            guard let currentNonce else {
                throw SignInWithAppleError.unableToFindNonce
            }
            
            guard let result = SignInWithAppleResult(authorization: authorization, nonce: currentNonce) else {
                throw SignInWithAppleError.badResponse
            }
            
            completionHandler?(.success(result))
        } catch {
            completionHandler?(.failure(error))
            return
        }
    }
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completionHandler?(.failure(error))
        return
    }
}

//MARK: ASAuthorizationControllerPresentationContextProviding
@MainActor
extension UIViewController: @retroactive ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
}
