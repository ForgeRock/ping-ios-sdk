// 
//  IdpValidationUtils.swift
//  ExternalIdP
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import UIKit

/// Utility class for common IdP validation operations
@MainActor
public struct IdpValidationUtils {
    
    /// Validates that a top view controller is available for presenting authentication UI
    /// - Returns: The top view controller
    /// - Throws: IdpExceptions.illegalStateException if no view controller is found
    public static func validateTopViewController() throws -> UIViewController {
        guard let topVC = IdpClient.getTopViewController() else {
            throw IdpExceptions.illegalStateException(message: IdpErrorMessages.missingViewController)
        }
        return topVC
    }
    
    /// Validates that a client ID is provided and not empty
    /// - Parameter clientId: The client ID to validate
    /// - Parameter provider: The name of the provider (for error messaging)
    /// - Throws: IdpExceptions.illegalArgumentException if client ID is invalid
    public static func validateClientId(_ clientId: String?, provider: String) throws {
        guard let clientId = clientId, !clientId.isEmpty else {
            throw IdpExceptions.illegalArgumentException(message: "\(provider) authentication requires a valid client ID")
        }
    }
}

/// Centralized error messages for IdP operations
public struct IdpErrorMessages {
    
    // MARK: - Common Errors
    public static let missingViewController = "Unable to find the top view controller for authentication"
    public static let invalidConfiguration = "Invalid authentication configuration provided"
    public static let userCancelled = "User cancelled the authentication process"
    public static let idpFetchFailed = "IdpClient fetch failed: "
    
    // MARK: - Apple Sign-In Errors
    public static let appleTokenMissing = "Apple Sign In completed but no identity token was received"
    public static let appleEncodingFailed = "Failed to encode Apple Sign In response to JSON format"
    public static let appleSignInFailed = "Apple Sign In failed"
    
    // MARK: - Google Sign-In Errors
    public static let googleClientIdMissing = "Google authentication requires a valid client ID"
    public static let googleTokenMissing = "Google Sign In completed but no identity token was received"
    public static let googleResultMissing = "Google Sign In completed but no result token was received"
    public static let googleUserMissing = "Google Sign In completed but no user token was received"
    
    // MARK: - Facebook Sign-In Errors
    public static let facebookTokenMissing = "Facebook login completed but no access token was received"
    public static let facebookConfigurationInvalid = "Facebook login configuration is invalid"
    public static let facebookManagerMissing = "Facebook login manager is not initialized"
}

public struct IdpConstants {
    public static let id_token = "id_token"
    public static let access_token = "access_token"
}
