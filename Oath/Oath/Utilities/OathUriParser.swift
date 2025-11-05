//
//  OathUriParser.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingMfaCommons

/// Utility class for parsing and formatting OATH URIs.
/// Supports both otpauth:// and mfauth:// schemes as defined in RFC specifications.
///
/// This parser handles the standard OATH URI format used by authenticator applications
/// and supports additional parameters for enhanced functionality.
enum OathUriParser {

    // MARK: - Constants

    /// OATH URI parameter names
    private static let secretParam = "secret"
    private static let algorithmParam = "algorithm"
    private static let digitsParam = "digits"
    private static let periodParam = "period"
    private static let counterParam = "counter"
    private static let resourceIdParam = "oid" // OATH Resource ID parameter
    private static let policiesParam = "policies" // MFA policies (base64-encoded JSON)

    /// Default values for optional parameters
    private static let defaultAlgorithm = OathAlgorithm.sha1.rawValue
    private static let defaultDigits = 6
    private static let defaultPeriod = 30
    private static let defaultCounter = 0
    
    /// Security constants
    static let maxSecretLength = 1024
    static let maxParameterLength = 256
    static let maxUriLength = 4096

    
    // MARK: - Public Methods

    /// Parse an OATH URI string into an OathCredential.
    /// - Parameter uri: The URI string to parse.
    /// - Returns: A new OathCredential instance.
    /// - Throws: `OathError.invalidUri` if the URI is malformed.
    /// - Throws: `OathError.missingRequiredParameter` if required parameters are missing.
    /// - Throws: `OathError.invalidParameterValue` if parameter values are invalid.
    ///
    /// Supported formats:
    /// - `otpauth://totp/Issuer:AccountName?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30`
    /// - `otpauth://hotp/Issuer:AccountName?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&counter=0`
    /// - `mfauth://totp/Issuer:AccountName?secret=SECRET&issuer=Issuer&algorithm=SHA1&digits=6&period=30`
    ///
    /// Additional supported parameters:
    /// - `uid`: Base64-encoded user ID
    /// - `oid`: OATH resource/device ID
    /// - `image`: URL for issuer logo
    /// - `b`: Background color (hex format)
    /// - `policies`: Base64-encoded JSON policies (mfauth scheme only)
    static func parse(_ uri: String) async throws -> OathCredential {
        // Security check: URI length validation
        guard uri.count <= maxUriLength else {
            throw OathError.invalidUri("URI exceeds maximum allowed length")
        }
        
        // Security check: Validate against malicious characters
        try validateUriSecurity(uri)
        
        guard let url = URL(string: uri) else {
            throw OathError.invalidUri("Invalid URI format: \(uri)")
        }

        // Validate scheme using UriScheme from MfaCommons
        guard let uriScheme = UriScheme.from(url: url),
              uriScheme == .otpauth || uriScheme == .mfauth else {
            throw OathError.invalidUri("Unsupported URI scheme: \(url.scheme ?? "none")")
        }

        // Parse OATH type from authority
        guard let host = url.host else {
            throw OathError.invalidUri("Missing OATH type in URI")
        }

        let oathType: OathType
        switch host.lowercased() {
        case OathType.totp.rawValue:
            oathType = .totp
        case OathType.hotp.rawValue:
            oathType = .hotp
        default:
            throw OathError.invalidUri("Unknown OATH type: \(host)")
        }

        // Parse label (path component without leading slash)
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.isEmpty else {
            throw OathError.invalidUri("Missing label in URI")
        }
        
        // Security check: Validate path for directory traversal attacks
        try validatePathSecurity(path)

        // Parse query parameters
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var parameters: [String: String] = [:]
        
        for item in queryItems {
            guard let value = item.value else { continue }
            // Security check: Validate parameter values
            try validateParameterSecurity(name: item.name, value: value)
            parameters[item.name] = value
        }

        // Extract required secret parameter
        guard let secret = parameters[secretParam], !secret.isEmpty else {
            throw OathError.missingRequiredParameter("Missing or empty secret parameter")
        }
        
        // Security check: Validate secret parameter
        try validateSecretSecurity(secret)

        // Get issuer parameter and decode if needed for mfauth scheme
        var issuerParam = parameters[UriParser.issuerParam]
        if let issuer = issuerParam, !issuer.isEmpty, uriScheme == .mfauth {
            if Base64.isBase64Encoded(issuer) {
                issuerParam = try Base64.decodeBase64Url(issuer)
            }
        }

        // Extract issuer and account from label using base UriParser
        let parser = UriParser()
        let (issuer, accountName) = try parser.parseLabelComponents(path, issuerParam: issuerParam)

        // Parse optional parameters with defaults
        let algorithmString = parameters[algorithmParam] ?? defaultAlgorithm
        let algorithm = try OathAlgorithm.fromString(algorithmString)

        let digits = try parseIntParameter(parameters[digitsParam], defaultValue: defaultDigits, parameterName: "digits", validRange: 4...8)
        let period = try parseIntParameter(parameters[periodParam], defaultValue: defaultPeriod, parameterName: "period", validRange: 1...300)
        let counter = try parseIntParameter(parameters[counterParam], defaultValue: defaultCounter, parameterName: "counter", validRange: 0...Int.max)

        // Parse additional parameters
        let displayIssuer = issuerParam ?? issuer

        // User ID - might be base64-encoded for mfauth scheme
        var userId: String?
        if let userIdParam = parameters[UriParser.userIdParamOath] {
            if Base64.isBase64Encoded(userIdParam) {
                userId = try Base64.decodeBase64Url(userIdParam)
            } else {
                userId = userIdParam
            }
        }

        // Resource ID - typically base64-encoded
        var resourceId: String?
        if let resourceIdParam = parameters[resourceIdParam] {
            if Base64.isBase64Encoded(resourceIdParam) {
                resourceId = try Base64.decodeBase64Url(resourceIdParam)
            } else {
                resourceId = resourceIdParam
            }
        }
        
        // Policies - typically base64-encoded JSON string
        var policies: String?
        if let policiesParam = parameters[Self.policiesParam] {
            if Base64.isBase64Encoded(policiesParam) {
                policies = try Base64.decodeBase64Url(policiesParam)
            } else {
                policies = policiesParam
            }
        }
        
        // Image URL
        let imageURL = parameters[UriParser.imageUrlParam]

        // Background color - remove # prefix if present
        let backgroundColor = parser.formatBackgroundColor(parameters[UriParser.backgroundColorParam])

        // Create and return credential
        return OathCredential(
            userId: userId,
            resourceId: resourceId,
            issuer: issuer,
            displayIssuer: displayIssuer,
            accountName: accountName,
            displayAccountName: accountName,
            oathType: oathType,
            oathAlgorithm: algorithm,
            digits: digits,
            period: period,
            counter: counter,
            imageURL: imageURL,
            backgroundColor: backgroundColor,
            policies: policies,
            secretKey: secret
        )
    }

    /// Format an OathCredential into a URI string.
    /// - Parameter credential: The credential to format.
    /// - Returns: A properly formatted URI string.
    /// - Throws: `OathError.uriFormatting` if formatting fails.
    static func format(_ credential: OathCredential) async throws -> String {
        var components = URLComponents()
        components.scheme = UriScheme.otpauth.scheme
        components.host = credential.oathType.rawValue.lowercased()

        // Custom allowed character set for label components
        var labelAllowed = CharacterSet.urlPathAllowed
        labelAllowed.remove(charactersIn: "@:")
        func encodeLabelComponent(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: labelAllowed) ?? value
        }

        // Format the label part (issuer[:account]) with required percent-encoding rules
        let encodedIssuer = encodeLabelComponent(credential.issuer)
        let encodedAccount = encodeLabelComponent(credential.accountName)
        let label = credential.issuer.isEmpty ? encodedAccount : "\(encodedIssuer):\(encodedAccount)"
        components.percentEncodedPath = "/\(label)"

        // Build query parameters
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: secretParam, value: credential.secret))
        if !credential.issuer.isEmpty {
            queryItems.append(URLQueryItem(name: UriParser.issuerParam, value: credential.displayIssuer))
        }
        if credential.oathAlgorithm != .sha1 {
            queryItems.append(URLQueryItem(name: algorithmParam, value: credential.oathAlgorithm.rawValue))
        }
        if credential.digits != defaultDigits {
            queryItems.append(URLQueryItem(name: digitsParam, value: String(credential.digits)))
        }
        switch credential.oathType {
        case .totp:
            if credential.period != defaultPeriod {
                queryItems.append(URLQueryItem(name: periodParam, value: String(credential.period)))
            }
        case .hotp:
            queryItems.append(URLQueryItem(name: counterParam, value: String(credential.counter)))
        }
        if let userId = credential.userId {
            let encodedUserId = Base64.encodeBase64(userId)
            queryItems.append(URLQueryItem(name: UriParser.userIdParamOath, value: encodedUserId))
        }
        if let resourceId = credential.resourceId {
            let encodedResourceId = Base64.encodeBase64(resourceId)
            queryItems.append(URLQueryItem(name: resourceIdParam, value: encodedResourceId))
        }
        if let imageURL = credential.imageURL {
            queryItems.append(URLQueryItem(name: UriParser.imageUrlParam, value: imageURL))
        }
        if let backgroundColor = credential.backgroundColor {
            queryItems.append(URLQueryItem(name: UriParser.backgroundColorParam, value: backgroundColor))
        }
        components.queryItems = queryItems

        guard let uri = components.url?.absoluteString else {
            throw OathError.uriFormatting("Failed to format credential as URI")
        }
        return uri
    }

    
    // MARK: - Private Helper Methods

    /// Parse an integer parameter with validation.
    /// - Parameters:
    ///   - value: The string value to parse.
    ///   - defaultValue: The default value if parsing fails.
    ///   - parameterName: The parameter name for error reporting.
    ///   - validRange: The valid range for the parameter value.
    /// - Returns: The parsed integer value.
    /// - Throws: `OathError.invalidParameterValue` if the value is invalid.
    private static func parseIntParameter(_ value: String?, defaultValue: Int, parameterName: String, validRange: ClosedRange<Int>) throws -> Int {
        guard let value = value else {
            return defaultValue
        }

        guard let intValue = Int(value), validRange.contains(intValue) else {
            throw OathError.invalidParameterValue("Invalid \(parameterName) value: \(value). Must be between \(validRange.lowerBound) and \(validRange.upperBound)")
        }

        return intValue
    }
    
    
    // MARK: - Security Validations

    /// Validate URI for security risks.
    /// - Parameter uri: The URI string to validate.
    /// - Throws: `OathError.invalidUri` if the URI is considered malicious.
    private static func validateUriSecurity(_ uri: String) throws {
        // Check for null bytes
        if uri.contains("\0") {
            throw OathError.invalidUri("URI contains null byte")
        }
        // Check for JavaScript injection
        if uri.range(of: "javascript:", options: .caseInsensitive) != nil {
            throw OathError.invalidUri("URI contains JavaScript injection attempt")
        }
        // Check for Unicode bidirectional override characters
        let bidiChars = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}")
        if uri.rangeOfCharacter(from: bidiChars) != nil {
            throw OathError.invalidUri("URI contains invalid Unicode characters")
        }
    }

    /// Validate path component for security risks.
    /// - Parameter path: The path component to validate.
    /// - Throws: `OathError.invalidUri` if the path is considered malicious.
    private static func validatePathSecurity(_ path: String) throws {
        // Check for directory traversal patterns
        let traversalPatterns = ["../", "..\\", "/..", "\\.."]
        for pattern in traversalPatterns {
            if path.contains(pattern) {
                throw OathError.invalidUri("Path traversal attempt detected")
            }
        }
    }

    /// Validate individual parameter for security risks.
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    /// - Throws: `OathError.invalidParameterValue` if the parameter is considered malicious.
    private static func validateParameterSecurity(name: String, value: String) throws {
        // Limit length to prevent DoS attacks
        guard value.count <= maxParameterLength else {
            throw OathError.invalidParameterValue("Parameter \(name) exceeds maximum length")
        }
        // Check for null bytes
        if value.contains("\0") {
            throw OathError.invalidParameterValue("Parameter \(name) contains null byte")
        }
        // Check for JavaScript injection
        if value.range(of: "javascript:", options: .caseInsensitive) != nil {
            throw OathError.invalidParameterValue("Parameter \(name) contains JavaScript injection attempt")
        }
        // Check for HTML/XML tags (XSS attempts)
        if value.contains("<") && value.contains(">") {
            throw OathError.invalidParameterValue("Parameter \(name) contains HTML/XML tags")
        }
        // Check for Unicode bidirectional override characters
        let bidiChars = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}")
        if value.rangeOfCharacter(from: bidiChars) != nil {
            throw OathError.invalidParameterValue("Parameter \(name) contains invalid Unicode characters")
        }
    }

    /// Validate secret parameter for security risks.
    /// - Parameter secret: The secret value to validate.
    /// - Throws: `OathError.invalidParameterValue` if the secret is considered malicious.
    private static func validateSecretSecurity(_ secret: String) throws {
        // Limit length to prevent DoS attacks
        guard secret.count <= maxSecretLength else {
            throw OathError.invalidParameterValue("Secret exceeds maximum length")
        }
        // Check for null bytes
        if secret.contains("\0") {
            throw OathError.invalidParameterValue("Secret contains null byte")
        }
        // Check for JavaScript injection
        if secret.range(of: "javascript:", options: .caseInsensitive) != nil {
            throw OathError.invalidParameterValue("Secret contains JavaScript injection attempt")
        }
        // Check for Unicode bidirectional override characters
        let bidiChars = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}")
        if secret.rangeOfCharacter(from: bidiChars) != nil {
            throw OathError.invalidParameterValue("Secret contains invalid Unicode characters")
        }
    }
}
