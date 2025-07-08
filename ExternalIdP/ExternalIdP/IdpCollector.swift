//
//  IdpCollector.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingDavinci

/// A collector class for handling Identity Provider (IdP) authorization.
/// - property continueNode: The continue node.
/// - property id: The unique identifier for the collector.
/// - property idpType: The type of IdP.
/// - property label: The label for the IdP.
/// - property link: The URL link for IdP authentication.
/// - property nativeHandler: The native handler for the IdP request.
/// - property resumeRequest: The request to resume the DaVinci flow.
@objc
open class IdpCollector: NSObject, Collector, ContinueNodeAware, RequestInterceptor, @unchecked Sendable {
    
    /// ContinueNode property
    public var continueNode: ContinueNode?
    
    /// The unique identifier for the collector.
    public var id: String {
        return UUID().uuidString
    }
    
    /// Indicates whether the IdP is enabled.
    public var idpEnabled = true
    
    ///  The IdP identifier.
    public var idpId: String
    
    /// The type of IdP.
    public var idpType: String
    
    ///  The label for the IdP.
    public var label: String
    
    ///  The URL link for IdP authentication.
    public var link: URL?
    
    /// The native handler for the IdP request.
    public var nativeHandler: IdpRequestHandler?
    
    ///  The request to resume the DaVinci flow.
    public var resumeRequest: Request?
    
    /// Initializes the `IdpCollector` with the given JSON input.
    public required init(with json: [String : Any]) {
        idpEnabled = json[Constants.idpEnabled] as? Bool ?? true
        idpId = json[Constants.idpId] as? String ?? ""
        idpType = json[Constants.idpType] as? String ?? ""
        label = json[Constants.label] as? String ?? ""
        if let links = json[Constants.links] as? [String: Any],
           let authenticate = links[Constants.authenticate] as? [String: Any],
           let href = authenticate[Constants.href] as? String {
            link = URL(string: href)
        }
    }
    
    /// Initializes the IdpCollector with a value.
    public func initialize(with value: Any) { }
    
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCollector() {
        Task {
            await CollectorFactory.shared.register(type: Constants.SOCIAL_LOGIN_BUTTON, collector: IdpCollector.self)
        }
    }
    
    /// Authorizes the IdP.
    /// - Parameter callbackURLScheme: The callback URL scheme.
    open func authorize(callbackURLScheme: String? = nil) async -> Result<Bool, IdpExceptions> {
        do {
            guard let url = link else {
                return .failure(.illegalArgumentException(message: "Missing link URL"))
            }
            let workflow = continueNode?.workflow
            if let httpClient = workflow?.config.httpClient, let handler = await getDefaultIdpHandler(httpClient: httpClient) {
                nativeHandler = handler
                return await self.authorize(handler: handler, url: url, callbackURLScheme: callbackURLScheme)
            }
            else {
                return await fallbackToBrowserHandler(callbackURLScheme: callbackURLScheme, url: url)
            }
        }
    }
    
    //MARK: RequestInterceptor
    /// Intercepts the request.
    ///  - Parameters:
    ///     - context: The flow context.
    ///     - request: The request to intercept.
    public func intercept(context: FlowContext, request: Request) -> Request {
        return resumeRequest ?? request
    }
    
    /// Function returning the `Payload` of the IdP collector. This is a function that returns `Never` as a _nonreturning_ function as the IDPCollector has no payload to return.
    public func payload() -> Never? {
        return nil
    }
    
    /// Gets the default IdP handler for the Provider. It will either be AppleRequestHandler, GoogleRequestHandler, FacebookRequestHandler
    /// - Parameters:
    ///  - httpClient: The HTTP client.
    ///  - Returns: The IdpRequestHandler.
    @MainActor public func getDefaultIdpHandler(httpClient: HttpClient) -> IdpRequestHandler? {
        switch idpType {
        case Constants.APPLE:
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPApple.AppleRequestHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c, httpClient: httpClient)
            } else {
                return nil
            }
        case Constants.GOOGLE:
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPGoogle.GoogleRequestHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c, httpClient: httpClient)
            } else {
                return nil
            }
        case Constants.FACEBOOK:
            if let c: NSObject.Type = NSClassFromString("PingExternalIdPFacebook.FacebookRequestHandler") as? NSObject.Type {
                return makeNativeRequestHandler(from: c, httpClient: httpClient)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    /// Creates a native request handler from the specified class.
    /// - Parameters:
    ///     - c: The class to create the handler from.
    ///     - httpClient: The HTTP client to use.
    /// - Returns: The IdpRequestHandler.
    private func makeNativeRequestHandler(from c: AnyClass, httpClient: HttpClient) -> IdpRequestHandler? {
        // 1) Cast the class object to NSObject.Type so we can call `perform(_:)` on it
        guard let nsObjcClass = c as? NSObject.Type else {
            // This is not an NSObject subclass
            return nil
        }
        
        // 2) Call +alloc
        let allocSel = NSSelectorFromString("alloc")
        guard
            let allocUnmanaged = nsObjcClass.perform(allocSel),
            let allocated = allocUnmanaged.takeUnretainedValue() as? NSObject
        else {
            // Couldn’t alloc
            return nil
        }
        
        // 3) Call -initWithHttpClient:
        let initSel = NSSelectorFromString("initWithHttpClient:")
        guard
            let initUnmanaged = allocated.perform(initSel, with: httpClient),
            let initialized = initUnmanaged.takeUnretainedValue() as? IdpRequestHandler
        else {
            // Couldn’t init \(c) with httpClient
            return nil
        }
        
        return initialized
    }
    
    /// Fallback to the browser handler.
    /// - Parameters:
    ///  - callbackURLScheme: The callback URL scheme.
    ///  - url: The URL for the IdP authentication.
    /// - Returns: A Result of type Bool or An IdpExceptions error.
    public func fallbackToBrowserHandler(callbackURLScheme: String? = nil, url: URL) async -> Result<Bool, IdpExceptions> {
        let urlScheme: String
        if let customScheme = callbackURLScheme {
            urlScheme = customScheme
        } else {
            guard let urlSchemes = getCustomURLSchemes(), let scheme = urlSchemes.first else {
                return .failure(.illegalArgumentException(message: "Missing custom URL schemes"))
            }
            urlScheme = scheme
        }
        do {
            guard let continueNode = continueNode else {
                return .failure(.illegalArgumentException(message: "Missing continue node"))
            }
            let request = try await BrowserHandler(continueNode: continueNode, callbackURLScheme: urlScheme).authorize(url: url)
            self.resumeRequest = request
            return .success(true)
        } catch {
            return .failure(.idpCanceledException(message: error.localizedDescription))
        }
    }
    
    /// Authorizes the IdP
    ///  - Parameters:
    ///    - handler: The IdpRequestHandler.
    ///    - url: The URL for the IdP authentication.
    ///    - callbackURLScheme: The callback URL scheme.
    ///  - Returns: A Result of type Bool or An IdpExceptions error.
    private func authorize(handler: IdpRequestHandler, url: URL, callbackURLScheme: String? = nil) async -> Result<Bool, IdpExceptions> {
        do {
            let request = try await handler.authorize(url: url)
            self.resumeRequest = request
            return .success(true)
        } catch let error as IdpExceptions {
            switch error {
            case .unsupportedIdpException:
                return .failure(.unsupportedIdpException(message: "No Supported IdP handler found"))
            default:
                return .failure(error)
            }
        } catch {
            return .failure(.idpCanceledException(message: error.localizedDescription))
        }
    }
    
    /// Gets the CustomURLSchemes for the Xcode project.
    /// - Returns: An array of custom URL schemes.
    private func getCustomURLSchemes() -> [String]? {
        if let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] {
            for urlType in urlTypes {
                if let urlSchemes = urlType["CFBundleURLSchemes"] as? [String] {
                    return urlSchemes  // Return the first set of schemes found
                }
            }
        }
        return nil
    }
}
