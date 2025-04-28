//
//  IdpCollector.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingDavinci

/*
public protocol IdpCollector: NSObject, Sendable {
    /// ContinueNode property
    var continueNode: ContinueNode? { get set }
    
    /// The unique identifier for the collector.
    var id: String { get }
    
    /// Indicates whether the IdP is enabled.
    var idpEnabled: Bool { get set }
    
    ///  The IdP identifier.
    var idpId: String { get set }
    
    /// The type of IdP.
    var idpType: String { get set }
    
    ///  The label for the IdP.
    var label: String { get set }
    
    ///  The URL link for IdP authentication.
    var link: URL? { get set }
    
    /// The native handler for the IdP request.
    var nativeHandler: IdpRequestHandler? { get set }
    
    ///  The request to resume the DaVinci flow.
    var resumeRequest: Request? { get set }
    
    func authorize(callbackURLScheme: String?) async -> Result<Bool, IdpExceptions> 
}
*/
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
            return await self.fallbackToBrowserHandler(callbackURLScheme: callbackURLScheme, url: url)
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
