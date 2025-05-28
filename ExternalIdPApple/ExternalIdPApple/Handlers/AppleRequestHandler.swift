//
//  AppleRequestHandler.swift
//  ExternalIdPApple
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import AuthenticationServices
import PingExternalIdP

///IdpHandler for Apple
@MainActor
@objc class AppleRequestHandler: NSObject, IdpRequestHandler {
    /// The HTTP client to use for requests.
    private let httpClient: HttpClient
    /// The IdpClient to use for requests.
    private var idpClient: IdpClient?
    
    /// Initializes a new instance of `AppleRequestHandler`.
    /// - Parameter httpClient: The HTTP client to use for requests.
    @objc(initWithHttpClient:)
    init(httpClient: HttpClient) {
        self.httpClient = httpClient
    }
    
    /// Authorizes the user with the IDP.
    /// - Parameter url: The URL for the IDP.
    /// - Returns: A `Request` object containing the result of the authorization.
    func authorize(url: URL?) async throws -> Request {
        do {
            self.idpClient = try await self.fetch(httpClient: self.httpClient, url: url)
        } catch {
            throw IdpExceptions.unsupportedIdpException(message: "IdpClient fetch failed: \(error.localizedDescription)")
        }
        guard let idpClient = self.idpClient else {
            throw IdpExceptions.unsupportedIdpException(message: "IdpClient is nil")
        }
        let result = try await self.authorize(idpClient: idpClient)
        guard let continueUrl = idpClient.continueUrl, !continueUrl.isEmpty else {
            throw IdpExceptions.illegalStateException(message: "continueUrl is missing or empty")
        }
        let request = Request(urlString: continueUrl)
        request.header(name: Request.Constants.accept, value: Request.ContentType.json.rawValue)
        request.body(body: [Request.Constants.idToken: result.token])
        return request
    }
    
    /// Authorizes the user with the IDP, based on the IdpClient.
    /// - Parameter idpClient: The `IdpClient` to use for authorization.
    /// - Returns: An `IdpResult` object containing the result of the authorization.
    private func authorize(idpClient: IdpClient) async throws -> IdpResult {
        let helper = SignInWithAppleHelper(idpClient: idpClient)
        
        // Sign in to Apple account
        for try await appleResponse in helper.startSignInWithAppleFlow() {
            let token = appleResponse.token
            
            let nonce = appleResponse.nonce
            let displayName = appleResponse.displayName ?? ""
            let firstName = appleResponse.firstName ?? ""
            let lastName = appleResponse.lastName ?? ""
            let email = appleResponse.email ?? ""
            
            return IdpResult(token: token, additionalParameters: ["name": displayName, "firstName": firstName, "lastName": lastName, "nonce": nonce, "email": email])
        }
        throw IdpExceptions.illegalStateException(message: "Apple Sign In failed")
    }
}

/// Represents the result of a Sign In With Apple request.
struct SignInWithAppleResult: Sendable {
    /// The token returned by Apple.
    let token: String
    /// The nonce used for the request.
    let nonce: String
    /// The email returned by Apple. Optional
    let email: String?
    /// The first name returned by Apple. Optional
    let firstName: String?
    /// The last name returned by Apple. Optional
    let lastName: String?
    /// The nickName returned by Apple. Optional
    let nickName: String?
    
    /// Full name computed property, combining first and last name.
    var fullName: String? {
        if let firstName, let lastName {
            return firstName + " " + lastName
        } else if let firstName {
            return firstName
        } else if let lastName {
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
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let appleIDToken = appleIDCredential.identityToken,
            let token = String(data: appleIDToken, encoding: .utf8)
        else {
            return nil
        }
        
        self.token = token
        self.nonce = nonce
        self.email = appleIDCredential.email
        self.firstName = appleIDCredential.fullName?.givenName
        self.lastName = appleIDCredential.fullName?.familyName
        self.nickName = appleIDCredential.fullName?.nickname
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
