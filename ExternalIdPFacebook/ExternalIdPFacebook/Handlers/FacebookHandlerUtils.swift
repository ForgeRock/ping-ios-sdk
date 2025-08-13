// 
//  FacebookHandlerUtils.swift
//  ExternalIdPFacebook
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOrchestrate
import FBSDKLoginKit
import FBSDKCoreKit
import UIKit
import PingExternalIdP

/// Utility class for handling Facebook IDP authorization.
@MainActor
class FacebookHandlerUtils {
    
    /// Authorizes the user with Facebook IDP using the provided configuration and manager.
    /// - Parameters:
    ///  - idpClient: The IDP client used for the authorization.
    ///  - configuration: The login configuration containing the necessary parameters for the Facebook login.
    ///  - manager: The login manager used to handle the Facebook login process.
    ///  - Returns: An `IdpResult` containing the access token and additional parameters.
    ///  - Throws: An error if the authorization fails, such as missing configuration or user cancellation.
    static func authorize(idpClient: IdpClient, configuration: LoginConfiguration?, manager: LoginManager?) async throws -> IdpResult {
        let topVC = try IdpValidationUtils.validateTopViewController()
        
        guard let validConfiguration = configuration else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.invalidConfiguration)
        }
        
        return try await withCheckedThrowingContinuation {  (continuation: CheckedContinuation<IdpResult, Error>) in
            guard let manager = manager else {
                continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.facebookManagerMissing))
                return
            }
            Task { @MainActor in
                manager.logIn(viewController: topVC, configuration: validConfiguration) { result in
                    switch result {
                    case .cancelled:
                        continuation.resume(throwing: IdpExceptions.idpCanceledException(message: IdpErrorMessages.userCancelled))
                    case .failed(let error):
                        continuation.resume(throwing: IdpExceptions.illegalStateException(message: error.localizedDescription))
                    case .success(_, _, let token):
                        guard let accessToken = token?.tokenString else {
                            continuation.resume(throwing: IdpExceptions.illegalStateException(message: IdpErrorMessages.facebookTokenMissing))
                            return
                        }
                        continuation.resume(returning: IdpResult(token: accessToken, additionalParameters: nil))
                    }
                }
            }
        }
    }
}
