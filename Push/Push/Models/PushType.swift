//
//  PushType.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Enum representing the different types of Push notifications.
///
/// Push notifications can be of different types depending on the authentication requirements:
/// - **DEFAULT**: Standard push notification requiring simple approval/denial
/// - **CHALLENGE**: Push notification requiring a challenge response (e.g., number matching)
/// - **BIOMETRIC**: Push notification requiring biometric authentication
///
/// ## Use Cases
///
/// - **DEFAULT**: Used for basic push authentication where the user simply approves or denies the request
/// - **CHALLENGE**: Used when additional verification is needed, such as number matching to prevent push bombing
/// - **BIOMETRIC**: Used when biometric verification (Touch ID, Face ID) is required for authentication
///
/// ## Standards Compliance
///
/// These types align with the push authentication mechanisms supported by PingAM
/// and other identity management platforms.
public enum PushType: String, CaseIterable, Codable, Sendable {
    
    /// Standard push notification requiring simple approval/denial.
    ///
    /// This is the most common type of push notification where the user receives
    /// a notification and can approve or deny the authentication request without
    /// any additional verification.
    ///
    /// **Characteristics:**
    /// - Simple user interaction (approve/deny)
    /// - No additional verification required
    /// - Fast authentication flow
    case `default` = "default"
    
    /// Push notification requiring a challenge response.
    ///
    /// This type requires the user to respond to a challenge, typically by entering
    /// or selecting a specific number shown in the authentication request. This helps
    /// prevent push bombing attacks where an attacker tries to gain access by repeatedly
    /// sending push notifications hoping the user will accidentally approve one.
    ///
    /// **Characteristics:**
    /// - Requires challenge response (e.g., number matching)
    /// - Higher security than default push
    /// - Prevents push bombing attacks
    case challenge = "challenge"
    
    /// Push notification requiring biometric authentication.
    ///
    /// This type requires the user to authenticate using biometric verification
    /// (Touch ID, Face ID, or other biometric methods) before approving the request.
    /// This provides the highest level of security for push authentication.
    ///
    /// **Characteristics:**
    /// - Requires biometric verification
    /// - Highest security level
    /// - Platform-specific biometric support required
    case biometric = "biometric"
    
    /// Creates a PushType from a string representation.
    ///
    /// This method allows parsing push types from strings in a case-insensitive manner,
    /// making it easier to work with data from various sources (APIs, URIs, etc.).
    ///
    /// - Parameter string: The string representation (case-insensitive).
    /// - Returns: The corresponding PushType.
    /// - Throws: `PushError.invalidPushType` if the string doesn't match any known type.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let type = try PushType.fromString("CHALLENGE") // Returns .challenge
    /// ```
    public static func fromString(_ string: String) throws -> PushType {
        switch string.lowercased() {
        case "default":
            return .default
        case "challenge":
            return .challenge
        case "biometric":
            return .biometric
        default:
            throw PushError.invalidPushType(string)
        }
    }
}
