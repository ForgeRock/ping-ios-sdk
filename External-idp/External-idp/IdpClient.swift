//
//  IdpClient.swift
//  External-idp
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import UIKit

/// Represents the IdpClient struct. The IdpClient struct represents the client configuration for the IDP.
/// - property clientId: The client ID.
/// - property redirectUri: The redirect URI.
/// - property scopes: The scopes.
/// - property nonce: The nonce.
/// - property continueUrl: The continue URL.
///
public struct IdpClient: Sendable {
    public var clientId: String? = nil
    public var redirectUri: String? = nil
    public var scopes: [String] = []
    public var nonce: String? = nil
    public var continueUrl: String? = nil
}

extension IdpClient {
    @MainActor
    static func getTopViewController() -> UIViewController? {
        // Get the active scene
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        let window = windowScene?.windows.first(where: { $0.isKeyWindow })
        
        // Get the root view controller
        guard var topController = window?.rootViewController else {
            return nil
        }
        
        // Navigate to the top-most presented controller
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        return topController
    }
}
