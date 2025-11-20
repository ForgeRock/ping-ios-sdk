//
//  PushUriParser.swift
//  PingPush
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingMfaCommons

/// Utility class for parsing and formatting Push URIs.
/// Supports both pushauth:// and mfauth:// schemes.
///
/// This parser handles the standard Push URI format used for credential registration
/// via QR codes and supports additional parameters for enhanced functionality.
///
/// ## URI Format
/// ```
/// pushauth://push/issuer:accountName?r=regEndpoint&a=authEndpoint&s=sharedSecret&d=userId
/// mfauth://push/issuer:accountName?r=regEndpoint&a=authEndpoint&s=sharedSecret&d=userId
/// ```
///
/// ## Required Parameters
/// - `r`: Registration endpoint (base64-encoded)
/// - `a`: Authentication endpoint (base64-encoded)
/// - `s`: Shared secret for signing (base64url-encoded)
///
/// ## Optional Parameters
/// - `d`: User ID (base64-encoded)
/// - `pid`: Push resource ID (base64-encoded)
/// - `issuer`: Issuer name (base64-encoded if from pushauth, plain if from mfauth)
/// - `image`: Image URL (base64-encoded)
/// - `b`: Background color (hex without #)
/// - `policies`: Authenticator policies (base64-encoded JSON)
/// - `c`: Challenge parameter for registration
/// - `l`: Load balancer cookie for registration
/// - `m`: Message ID for registration
public enum PushUriParser {
    
    // MARK: - Constants
    
    private static let pushauthScheme = "pushauth"
    private static let pushPath = "push"
    
    // Required parameters
    private static let sharedSecretParam = "s"          // Shared secret used for signing
    private static let regEndpointParam = "r"           // Registration endpoint
    private static let authEndpointParam = "a"          // Authentication endpoint
    
    // Optional parameters (for registration)
    private static let challengeParam = "c"             // Challenge parameter for registration response
    private static let loadBalancerParam = "l"          // Load Balancer cookie
    private static let messageIdParam = "m"             // Message ID for registration response
    private static let pushResourceIdParam = "pid"      // Push Resource ID
    
    // MARK: - Parsing
    
    /// Parse a Push URI string into a PushCredential.
    ///
    /// - Parameter uri: The URI string (pushauth:// or mfauth://).
    /// - Returns: A PushCredential instance.
    /// - Throws: `PushError.invalidUri` if the URI is malformed.
    public static func parse(_ uri: String) async throws -> PushCredential {
        guard let url = URL(string: uri) else {
            throw PushError.invalidUri("Cannot parse URI: \(uri)")
        }
        
        // Validate scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == pushauthScheme || scheme == UriParser.mfauthScheme else {
            throw PushError.invalidUri("Invalid URI scheme: \(url.scheme ?? "nil"), expected: \(pushauthScheme) or \(UriParser.mfauthScheme)")
        }
        
        // Parse label (path without leading '/')
        let label = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Get query parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryParams = components?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
        
        // Get and decode issuer parameter if present
        var issuerParam: String?
        if let issuerValue = queryParams[UriParser.issuerParam] {
            issuerParam = try decodeIfNeeded(issuerValue, scheme: scheme)
        }
        
        // Parse label components using UriParser
        let parser = UriParser()
        let (issuer, accountName) = try parser.parseLabelComponents(label, issuerParam: issuerParam)
        
        // Use issuerParam if provided to preserve exact case
        let finalIssuer = issuerParam ?? issuer
        
        // Get and decode required parameters
        guard let regEndpoint = queryParams[regEndpointParam] else {
            throw PushError.invalidUri("Missing required parameter: \(regEndpointParam)")
        }
        
        guard queryParams[authEndpointParam] != nil else {
            throw PushError.invalidUri("Missing required parameter: \(authEndpointParam)")
        }
        
        guard let sharedSecret = queryParams[sharedSecretParam] else {
            throw PushError.invalidUri("Missing required parameter: \(sharedSecretParam)")
        }
        
        // Decode registration endpoint and extract server endpoint base
        let decodedRegEndpoint = try decodeBase64UrlIfNeeded(regEndpoint)
        let serverEndpoint = try extractServerEndpoint(decodedRegEndpoint)
        
        // Recode shared secret from base64url no-wrap to standard base64 no-wrap
        let decodedSharedSecret = try recodeBase64NoWrapUrlSafeToNoWrap(sharedSecret)
        
        // Parse optional parameters
        let userId = try decodeOptionalParam(queryParams[UriParser.userIdParam])
        let resourceId = try decodeOptionalParam(queryParams[pushResourceIdParam]) ?? ""
        let policies = try decodeOptionalParam(queryParams[UriParser.policiesParam]) ?? ""
        
        // Image URL - decode if pushauth scheme
        var imageURL: String?
        if let imageValue = queryParams[UriParser.imageUrlParam] {
            imageURL = scheme == pushauthScheme 
                ? try decodeBase64(imageValue)
                : imageValue
        }
        
        // Background color - add # prefix if not present
        var backgroundColor: String?
        if let colorValue = queryParams[UriParser.backgroundColorParam], !colorValue.isEmpty {
            backgroundColor = colorValue.hasPrefix("#") ? colorValue : "#\(colorValue)"
        }
        
        return PushCredential(
            userId: userId,
            resourceId: resourceId,
            issuer: finalIssuer,
            displayIssuer: finalIssuer,
            accountName: accountName,
            displayAccountName: accountName,
            serverEndpoint: serverEndpoint,
            sharedSecret: decodedSharedSecret,
            imageURL: imageURL,
            backgroundColor: backgroundColor,
            policies: policies,
            platform: .pingAM
        )
    }
    
    // MARK: - Helper Methods
    
    /// Decode a parameter if it's base64-encoded.
    /// Always uses base64url decoding for consistency with Android implementation.
    private static func decodeIfNeeded(_ value: String, scheme: String) throws -> String {
        if isBase64Encoded(value) {
            // Always use base64url decoding regardless of scheme
            // This matches Android behavior which always uses decodeBase64Url for issuer
            return try decodeBase64Url(value)
        }
        return value
    }
    
    /// Decode an optional parameter if it's base64-encoded.
    private static func decodeOptionalParam(_ value: String?) throws -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        return isBase64Encoded(value) ? try decodeBase64(value) : value
    }
    
    /// Decode a base64url-encoded string if it appears to be encoded.
    private static func decodeBase64UrlIfNeeded(_ value: String) throws -> String {
        return isBase64Encoded(value) ? try decodeBase64Url(value) : value
    }
    
    /// Extract the base server endpoint from a full URL.
    /// Removes query parameters and _action suffix.
    ///
    /// - Parameter url: The full URL with potential query parameters.
    /// - Returns: The base server endpoint URL without query parameters.
    /// - Throws: `PushError.invalidUri` if the URL is malformed.
    private static func extractServerEndpoint(_ url: String) throws -> String {
        let urlComponents: URLComponents?
        if #available(iOS 17.0, *) {
            urlComponents = URLComponents(string: url, encodingInvalidCharacters: true)
        } else {
            urlComponents = URLComponents(string: url)
        }

        guard let urlComponents else {
            throw PushError.invalidUri("Cannot parse server endpoint: \(url)")
        }
        
        // Get the base URL without query parameters
        var endpoint = ""
        if let scheme = urlComponents.scheme {
            endpoint += "\(scheme)://"
        }
        if let host = urlComponents.host {
            endpoint += host
        }
        if let port = urlComponents.port {
            endpoint += ":\(port)"
        }
        endpoint += urlComponents.path
        
        return endpoint
    }
    
    // MARK: - Base64 Encoding/Decoding
    
    /// Check if a string appears to be base64-encoded by attempting to decode it.
    /// This matches Android's implementation which tries decode operations.
    /// Also verifies the decoded data is valid UTF-8 to avoid false positives.
    private static func isBase64Encoded(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        
        // Try standard base64 first
        let paddedValue = addBase64Padding(value)
        if let data = Data(base64Encoded: paddedValue),
           String(data: data, encoding: .utf8) != nil {
            return true
        }
        
        // Try base64url (convert to standard base64 first)
        let standardBase64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddedStandard = addBase64Padding(standardBase64)
        if let data = Data(base64Encoded: paddedStandard),
           String(data: data, encoding: .utf8) != nil {
            return true
        }
        
        return false
    }
    
    /// Decode a base64-encoded string.
    private static func decodeBase64(_ value: String) throws -> String {
        let paddedValue = addBase64Padding(value)
        guard let data = Data(base64Encoded: paddedValue),
              let decoded = String(data: data, encoding: .utf8) else {
            throw PushError.invalidUri("Failed to decode base64 value")
        }
        return decoded
    }
    
    /// Decode a base64url-encoded string.
    private static func decodeBase64Url(_ value: String) throws -> String {
        // Convert base64url to standard base64
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        base64 = addBase64Padding(base64)
        
        guard let data = Data(base64Encoded: base64),
              let decoded = String(data: data, encoding: .utf8) else {
            throw PushError.invalidUri("Failed to decode base64url value")
        }
        return decoded
    }
    
    /// Add padding to a base64 string if needed.
    private static func addBase64Padding(_ value: String) -> String {
        let remainder = value.count % 4
        if remainder > 0 {
            return value + String(repeating: "=", count: 4 - remainder)
        }
        return value
    }
    
    /// Recode a base64url no-wrap string to standard base64 no-wrap.
    /// Converts URL-safe characters (- and _) to standard base64 characters (+ and /).
    /// Adds padding (=) if needed to ensure valid base64.
    private static func recodeBase64NoWrapUrlSafeToNoWrap(_ value: String) throws -> String {
        // Convert base64url to standard base64
        let base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let paddedBase64 = addBase64Padding(base64)
        
        // Validate it's valid base64
        guard Data(base64Encoded: paddedBase64) != nil else {
            throw PushError.invalidUri("Invalid base64 shared secret")
        }
        
        return paddedBase64
    }
    
    // MARK: - Registration Parameters
    
    /// Extract registration parameters from a Push URI.
    /// These parameters are used during the credential registration flow.
    ///
    /// - Parameter uri: The URI string (pushauth:// or mfauth://).
    /// - Returns: A dictionary containing registration parameters:
    ///   - "challenge": Challenge value for registration response (key: "c")
    ///   - "amlbCookie": Load balancer cookie for proper routing (key: "l")
    ///   - "messageId": Message ID for registration response (key: "m")
    /// - Throws: `PushError.invalidUri` if the URI cannot be parsed or required parameters are missing.
    ///
    /// ## Notes
    /// - All three parameters (challenge, loadBalancer, messageId) are **required**
    /// - Will throw if any parameter is missing (matches Android behavior)
    /// - The loadBalancer parameter is returned with key "amlbCookie" for consistency with the handler
    /// - Base64-encoded values are decoded automatically
    public static func registrationParameters(_ uri: String) async throws -> [String: String] {
        guard let url = URL(string: uri) else {
            throw PushError.invalidUri("Cannot parse URI: \(uri)")
        }
        
        // Get query parameters
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryParams = components?.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
        
        // Extract message ID parameter (m) - REQUIRED
        guard let messageId = queryParams[messageIdParam], !messageId.isEmpty else {
            throw PushError.invalidUri("Missing required parameter: \(messageIdParam)")
        }
        
        // Extract load balancer parameter (l) - REQUIRED
        guard let loadBalancer = queryParams[loadBalancerParam], !loadBalancer.isEmpty else {
            throw PushError.invalidUri("Missing required parameter: \(loadBalancerParam)")
        }
        
        // Decode load balancer using base64url (matches Android decodeBase64Url)
        let decodedLoadBalancer = isBase64Encoded(loadBalancer) 
            ? try decodeBase64Url(loadBalancer)
            : loadBalancer
        
        // Extract challenge parameter (c) - REQUIRED
        guard let challenge = queryParams[challengeParam], !challenge.isEmpty else {
            throw PushError.invalidUri("Missing required parameter: \(challengeParam)")
        }
        
        // Challenge is always base64url-encoded, recode to standard base64
        let decodedChallenge = try recodeBase64NoWrapUrlSafeToNoWrap(challenge)
        
        // Return the parameters with keys matching Android (PushConstants)
        return [
            "amlbCookie": decodedLoadBalancer,
            "messageId": messageId,
            "challenge": decodedChallenge
        ]
    }
    
    // MARK: - URI Formatting
    
    /// Format a PushCredential into a URI string.
    ///
    /// - Parameter credential: The PushCredential to format.
    /// - Returns: A pushauth:// URI string.
    /// - Throws: `PushError.uriFormatting` if formatting fails.
    ///
    /// ## Example Output
    /// ```
    /// pushauth://push/ForgeRock:user@example.com?r=...&a=...&s=...&issuer=ForgeRock
    /// ```
    public static func format(_ credential: PushCredential) async throws -> String {
        // Format the label part, preserving the colon character
        let encodedLabel: String
        if !credential.issuer.isEmpty {
            let encodedIssuer = urlEncode(credential.issuer)
            let encodedAccount = urlEncode(credential.accountName)
            encodedLabel = "\(encodedIssuer):\(encodedAccount)"
        } else {
            encodedLabel = urlEncode(credential.accountName)
        }
        
        // Create registration and authentication endpoints
        let regEndpoint = "\(credential.serverEndpoint)?_action=register"
        let authEndpoint = "\(credential.serverEndpoint)?_action=authenticate"
        
        // Encode the endpoints in Base64 (standard, not URL-safe)
        let encodedRegEndpoint = try encodeBase64(regEndpoint)
        let encodedAuthEndpoint = try encodeBase64(authEndpoint)
        
        // Start building the URI
        var uriBuilder = "\(pushauthScheme)://\(pushPath)/"
        uriBuilder += encodedLabel
        
        // Add required parameters with URL encoding applied to base64 values
        uriBuilder += "?\(regEndpointParam)="
        uriBuilder += urlEncode(encodedRegEndpoint)
        
        uriBuilder += "&\(authEndpointParam)="
        uriBuilder += urlEncode(encodedAuthEndpoint)
        
        uriBuilder += "&\(sharedSecretParam)="
        uriBuilder += try recodeBase64NoWrapToUrlSafeNoWrap(credential.sharedSecret)
        
        // Add issuer parameter if present
        if !credential.issuer.isEmpty {
            uriBuilder += "&\(UriParser.issuerParam)="
            uriBuilder += urlEncode(credential.issuer)
        }
        
        // Add optional parameters if present
        if let userId = credential.userId, !userId.isEmpty {
            let encodedUserId = try encodeBase64(userId)
            uriBuilder += "&\(UriParser.userIdParam)="
            uriBuilder += urlEncode(encodedUserId)
        }
        
        if !credential.resourceId.isEmpty {
            let encodedResourceId = try encodeBase64(credential.resourceId)
            uriBuilder += "&\(pushResourceIdParam)="
            uriBuilder += urlEncode(encodedResourceId)
        }
        
        // Add image URL if present
        if let imageURL = credential.imageURL, !imageURL.isEmpty {
            let encodedImageURL = try encodeBase64(imageURL)
            uriBuilder += "&\(UriParser.imageUrlParam)="
            uriBuilder += urlEncode(encodedImageURL)
        }
        
        // Format background color (removing # if present)
        if let backgroundColor = credential.backgroundColor, !backgroundColor.isEmpty {
            let parser = UriParser()
            let colorValue = parser.formatBackgroundColor(backgroundColor) ?? backgroundColor
            uriBuilder += "&\(UriParser.backgroundColorParam)="
            uriBuilder += urlEncode(colorValue)
        }
        
        // Add policies if present
        // Add policies if present
        if let policies = credential.policies, !policies.isEmpty {
            let encodedPolicies = try encodeBase64(policies)
            uriBuilder += "&\(UriParser.policiesParam)="
            uriBuilder += urlEncode(encodedPolicies)
        }
        
        return uriBuilder
    }
    
    // MARK: - Base64 Encoding
    
    /// Encode a string to Base64URL (URL-safe base64 with no wrap).
    /// This matches Android's encodeBase64() which uses Base64.NO_WRAP or Base64.URL_SAFE.
    /// The result uses - and _ instead of + and /, and has no padding (=).
    private static func encodeBase64(_ value: String) throws -> String {
        guard let data = value.data(using: .utf8) else {
            throw PushError.uriFormatting("Failed to encode string to UTF-8")
        }
        // Encode to base64url (URL-safe variant with no padding)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// Recode a standard base64 string to base64url (URL-safe) no-wrap format.
    /// Converts standard base64 characters (+ and /) to URL-safe characters (- and _).
    /// Removes padding (=).
    private static func recodeBase64NoWrapToUrlSafeNoWrap(_ value: String) throws -> String {
        // Convert to URL-safe base64 by replacing characters
        // No need to decode/encode - just character replacement
        return value
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// URL encode a string for use in URI query parameters.
    /// This matches Android's Uri.encode() behavior, encoding all special characters
    /// except alphanumeric, hyphen, underscore, period, and tilde.
    /// - Parameter value: The string to encode
    /// - Returns: The URL-encoded string
    private static func urlEncode(_ value: String) -> String {
        // Create a character set for characters that DON'T need encoding
        // This matches Android Uri.encode() behavior
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
