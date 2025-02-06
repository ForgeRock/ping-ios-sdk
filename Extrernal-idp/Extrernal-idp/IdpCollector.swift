//
//  IdpCollector.swift
//  Extrernal-idp
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import PingDavinci

public class IdpCollector: Collector, ContinueNodeAware, RequestInterceptor {
    
    public var continueNode: PingOrchestrate.ContinueNode?
    
    public var id: UUID = UUID()
    
    /**
     * Indicates whether the IdP is enabled.
     */
    var idpEnabled = true
    
    /**
     * The IdP identifier.
     */
    var idpId: String
    
    /**
     * The type of IdP.
     */
    public var idpType: String
    
    /**
     * The label for the IdP.
     */
    public var label: String
    
    /**
     * The URL link for IdP authentication.
     */
    public var link: URL?
    
    /**
     * The request to resume the DaVinci flow.
     */
    private var resumeRequest: Request?
    
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
    
    public func authorize() async -> Result<Bool, IdpExceptions> {
        do {
            
            guard let url = link else {
                return .failure(.illegalArgumentException(message: "Missing link URL"))
            }
            
            let request = try await BrowserHandler(continueNode: continueNode!, tokenType: "code", callbackURLScheme: "myApp").authorize(url: url)
            self.resumeRequest = request
            
            return .success(true)
        } catch {
            print("ERROR...")
            return .failure(.idpCanceledException(message: "IDP Cancelled"))
        }
    }
    
    //MARK: RequestInterceptor
    public func intercept(context: FlowContext, request: Request) -> Request {
        return resumeRequest ?? request
    }
}
