//
//  NativeIdpCollector.swift
//  PingExternal-idp-native-handlers
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingExternal_idp
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
public class NativeIdpCollector: IdpCollector, @unchecked Sendable {
    
    /// Registers the IdpCollector with the collector factory
    @objc
    public static func registerNativeCollector() {
        Task {
            await CollectorFactory.shared.register(type: Constants.SOCIAL_LOGIN_BUTTON, collector: NativeIdpCollector.self)
        }
    }
    
    /// Authorizes the IdP.
    /// - Parameter callbackURLScheme: The callback URL scheme.
    public override func authorize(callbackURLScheme: String? = nil) async -> Result<Bool, IdpExceptions> {
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
    
    /// Gets the default IdP handler for the Provider. It will either be AppleRequestHandler, GoogleRequestHandler, FacebookRequestHandler
    /// - Parameters:
    ///  - httpClient: The HTTP client.
    ///  - Returns: The IdpRequestHandler.
    @MainActor public func getDefaultIdpHandler(httpClient: HttpClient) -> IdpRequestHandler? {
        switch idpType {
        case Constants.APPLE:
            return AppleRequestHandler(httpClient: httpClient)
        case Constants.GOOGLE:
            return GoogleRequestHandler(httpClient: httpClient)
        case Constants.FACEBOOK:
            return FacebookRequestHandler(httpClient: httpClient)
        default:
            return nil
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
}
