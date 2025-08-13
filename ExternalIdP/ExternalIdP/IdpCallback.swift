//
//  IdpCallback.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingJourney

@objc
class IdpCallbacks: NSObject {
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCallbacks() {
        CallbackRegistry.shared.register(type: "IdPCallback", callback: IdpCallback.self)
        CallbackRegistry.shared.register(type: "SelectIdPCallback", callback: SelectIdpCallback.self)
    }
}

/// A callback that handles federated authentication with an external Identity Provider (IdP) like Google, Facebook, or Apple.
///
/// This callback provides all the necessary configuration from the authentication server to perform
/// OAuth 2.0 / OpenID Connect flows with external identity providers. It supports both native SDK
/// integration and browser-based flows.
///
/// ## Usage Example
/// ```swift
/// // The callback is automatically created from server response
/// if let idpCallback = callback as? IdpCallback {
///     let result = await idpCallback.authorize()
///     switch result {
///     case .success(let idpResult):
///         // Authentication successful, proceed with next step
///         await continueNode.next()
///     case .failure(let error):
///         // Handle authentication error
///         print("Authentication failed: \(error)")
///     }
/// }
/// ```
///
/// ## Supported Providers
/// - Apple Sign In (Sign in with Apple)
/// - Google Sign-In
/// - Facebook Login
///
public final class IdpCallback: AbstractCallback, JourneyAware, RequestInterceptor, @unchecked Sendable {
    
    // MARK: - JourneyAware Conformance
    public var journey: Journey?
    
    // MARK: - Public Properties
    
    /// The name of the identity provider (e.g., "google", "facebook").
    public private(set) var provider: String = ""
    
    /// The client ID for the application registered with the IdP.
    public private(set) var clientId: String = ""
    
    /// The redirect URI configured for the IdP application.
    public private(set) var redirectUri: String = ""
    
    /// A list of OAuth 2.0 scopes to request from the IdP.
    public private(set) var scopes: [String] = []
    
    /// A unique value associated with the request to prevent replay attacks.
    public private(set) var nonce: String = ""
    
    /// A list of Authentication Context Class Reference values.
    public private(set) var acrValues: [String] = []
    
    /// A signed JWT containing the request parameters.
    public private(set) var request: String = ""
    
    /// A URL where the request object can be fetched.
    public private(set) var requestUri: String = ""
    
    /// The native handler for the IdP request.
    public private(set) var nativeHandler: IdpHandler?
    
    /// Indicates whether the callback accepts JSON responses.
    public private(set) var acceptsJSON: Bool = false
    
    // MARK: - Private State
    
    var result: IdpResult = IdpResult(token: "", additionalParameters: [:])
    var tokenType: String = ""
    
    // MARK: - Initialization and Parsing
    
    /// Initializes a new instance of `IdpCallback` with the provided JSON input.
    /// - Parameters:
    ///  - name: The name of the callback.
    ///  - value: The JSON value containing the IdP configuration.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.provider:
            self.provider = value as? String ?? ""
        case JourneyConstants.clientId:
            self.clientId = value as? String ?? ""
        case JourneyConstants.redirectUri:
            self.redirectUri = value as? String ?? ""
        case JourneyConstants.scopes:
            self.scopes = value as? [String] ?? []
        case JourneyConstants.nonce:
            self.nonce = value as? String ?? ""
        case JourneyConstants.acrValues:
            self.acrValues = value as? [String] ?? []
        case JourneyConstants.request:
            self.request = value as? String ?? ""
        case JourneyConstants.requestUri:
            self.requestUri = value as? String ?? ""
        case JourneyConstants.acceptsJSON:
            self.acceptsJSON = value as? Bool ?? false
        default:
            break
        }
    }
    
    // MARK: - Payload and Interception
    
    /// Constructs the final payload with the token received from the IdP.
    /// This method returns a dictionary containing the token and its type,
    /// or the JSON response if `acceptsJSON` is true.
    /// - Returns: A dictionary containing the token and its type.
    public override func payload() -> [String: Any] {
        if self.acceptsJSON, let jsonResponse = self.result.additionalParameters?[JourneyConstants.acceptsJSON] as? String {
            return input(jsonResponse, "JSON")
        } else {
            return input(self.result.token, self.tokenType)
        }
    }
    
    /// A closure that modifies the outgoing request to include additional parameters from the IdP result.
    /// This is used to add parameters to the request if the IdP does not accept JSON responses.
    /// - Parameters:
    ///  - context: The flow context containing the current state of the flow.
    ///  - request: The outgoing request to be modified.
    /// - Returns:
    ///  - Request: The modified request with additional parameters added, if applicable.
    public func intercept(context: FlowContext, request: Request) -> Request {
        if self.acceptsJSON == false {
            let newRequest = request
            guard let additionalParameters = self.result.additionalParameters else {
                return newRequest
            }
            for (key, value) in additionalParameters {
                newRequest.parameter(name: key, value: value)
            }
            return newRequest
        }
        return request
    }
    
    // MARK: - Public Methods
    
    /// Initiates the authorization flow with the configured identity provider.
    ///
    /// This method selects the appropriate `IdpHandler` based on the `provider` string
    /// and invokes its `authorize` method. On success, it stores the token result
    /// to be sent back to the authentication server.
    ///
    /// - Parameter idpHandler: An optional, specific handler to use. If nil, a handler is chosen automatically.
    /// - Throws: `IdpError.unsupportedProvider` if no handler can be found, or `IdpError.authorizationFailed` if the provider's flow fails.
    @MainActor
    public func authorize(idpHandler: IdpHandler? = nil) async -> Result<IdpResult, IdpExceptions> {
        let localHandler: IdpHandler
        // If a specific handler is provided, use it; otherwise, get the default handler based on the provider.
        if let handler = idpHandler {
            nativeHandler = handler
            localHandler = handler
        } else if let handler = getDefaultIdpHandler() {
            nativeHandler = handler
            localHandler = handler
        } else {
            return Result.failure(IdpExceptions.unsupportedIdpException(message: self.provider))
        }
        do {
            let client = IdpClient(clientId: self.clientId, redirectUri: self.redirectUri, scopes: self.scopes, nonce: self.nonce)
            self.result = try await localHandler.authorize(idpClient: client)
            self.tokenType = localHandler.tokenType
        } catch {
            return Result.failure(IdpExceptions.illegalStateException(message: error.localizedDescription))
        }
        
        return Result.success(self.result)
    }
    
    // MARK: - Private Helpers
    /// Gets the default IdP handler for the Provider. It will either be AppleRequestHandler, GoogleRequestHandler, FacebookRequestHandler
    /// - Parameters:
    ///  - httpClient: The HTTP client.
    ///  - Returns: The IdpRequestHandler.
    @MainActor private func getDefaultIdpHandler() -> IdpHandler? {
        let lowercasedProvider = provider.lowercased()
        
        // We switch on `true` and check boolean conditions in each case.
        switch true {
        case lowercasedProvider.contains(JourneyConstants.APPLE) || lowercasedProvider.contains(JourneyConstants.SIWA):
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPApple.AppleHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c)
            } else {
                return nil
            }
            
        case lowercasedProvider.contains(JourneyConstants.GOOGLE):
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPGoogle.GoogleHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c)
            } else {
                return nil
            }
            
        case lowercasedProvider.contains(JourneyConstants.FACEBOOK):
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPFacebook.FacebookHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c)
            } else {
                return nil
            }
            
        default:
            return nil
        }
    }
    
    /// Creates an instance of the IdpHandler from the provided class type.
    /// This method ensures that the class conforms to `NSObject` and `IdpHandler`
    /// and initializes it safely.
    /// - Parameter c: The class type to instantiate.
    /// - Returns: An instance of `IdpHandler` if successful, or nil if the class does not conform to the required types.
    @MainActor
    private func makeNativeRequestHandler(from c: AnyClass) -> IdpHandler? {
        // 1) Ensure the class type is an NSObject subclass that conforms to IdpHandler.
        guard let handlerClass = c as? (NSObject & IdpHandler).Type else {
            // The provided class 'c' does not conform to the required types.
            return nil
        }
        
        // 2) Directly initialize an instance of the class.
        // This is type-safe and checked by the compiler.
        let initializedHandler = handlerClass.init()
        
        return initializedHandler
    }
}
