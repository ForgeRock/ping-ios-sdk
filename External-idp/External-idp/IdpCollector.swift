//
//  IdpCollector.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
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
@objc
public class IdpCollector: NSObject, Collector, ContinueNodeAware, RequestInterceptor {
    
    /// ContinueNode property
    public var continueNode: PingOrchestrate.ContinueNode?
    
    /// The unique identifier for the collector.
    public var id: UUID = UUID()
    
    /// Indicates whether the IdP is enabled.
    var idpEnabled = true
    
    ///  The IdP identifier.
    var idpId: String
    
    /// The type of IdP.
    public var idpType: String
    
    ///  The label for the IdP.
    public var label: String
    
    ///  The URL link for IdP authentication.
    public var link: URL?
    
    ///  The request to resume the DaVinci flow.
    private var resumeRequest: Request?
    
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
    
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerCollector() {
        CollectorFactory.shared.register(type: Constants.SOCIAL_LOGIN_BUTTON, collector: IdpCollector.self)
    }
    
    /// Authorizes the IdP.
    /// - Parameter callbackURLScheme: The callback URL scheme.
    public func authorize(callbackURLScheme: String? = nil) async -> Result<Bool, IdpExceptions> {
        do {
            
            guard let url = link else {
                return .failure(.illegalArgumentException(message: "Missing link URL"))
            }
            
            let urlScheme: String
            if let customScheme = callbackURLScheme {
                urlScheme = customScheme
            } else {
                guard let urlSchemes = getCustomURLSchemes(), let scheme = urlSchemes.first else {
                    return .failure(.illegalArgumentException(message: "Missing custom URL schemes"))
                }
                urlScheme = scheme
            }
            
            
            let request = try await BrowserHandler(continueNode: continueNode!, tokenType: "code", callbackURLScheme: urlScheme).authorize(url: url)
            self.resumeRequest = request
            
            return .success(true)
        } catch {
            return .failure(.idpCanceledException(message: "IDP Cancelled"))
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
    
    /// Gets the CustomURLSchemes for the Xcode project.
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
