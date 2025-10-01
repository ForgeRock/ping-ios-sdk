//
//  UriParser.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Base class for URI parsers with common functionality.
public final class UriParser: Sendable {

    // MARK: - Common Parameters
    public static let mfauthScheme = "mfauth"
    public static let issuerParam = "issuer"
    public static let userIdParam = "d"
    public static let userIdParamOath = "uid"
    public static let imageUrlParam = "image"
    public static let backgroundColorParam = "b"
    public static let policiesParam = "policies"

    public init() {}

    // MARK: - Label Parsing

    /// Parses the issuer and account name from the label component of a URI.
    ///
    /// - Parameters:
    ///   - label: The label from the URI path (format: "Issuer:AccountName").
    ///   - issuerParam: The issuer from the URI query parameter (optional).
    /// - Returns: A tuple containing the issuer and account name.
    /// - Throws: `UriParseError.issuerMismatch` if the issuer parameter doesn't match the label issuer.
    public func parseLabelComponents(_ label: String, issuerParam: String?) throws -> (issuer: String, accountName: String) {
        // Try to split label into issuer and accountName
        let labelComponents = label.components(separatedBy: ":")

        switch labelComponents.count {
        case 2:
            // Label has the form "Issuer:AccountName"
            let labelIssuer = labelComponents[0]
            let accountName = labelComponents[1]

            // Verify that issuerParam matches the label issuer, if both are present
            if let issuerParam = issuerParam,
               !labelIssuer.isEmpty,
               issuerParam.caseInsensitiveCompare(labelIssuer) != .orderedSame {
                throw UriParseError.issuerMismatch(
                    parameterIssuer: issuerParam,
                    labelIssuer: labelIssuer
                )
            }

            // Use the label issuer if it exists, otherwise use the parameter
            let issuer = labelIssuer.isEmpty ? (issuerParam ?? "") : labelIssuer

            return (issuer: issuer, accountName: accountName)

        case 1 where !label.isEmpty:
            // Label doesn't have a colon, treat the whole label as accountName
            let issuer = issuerParam ?? ""
            return (issuer: issuer, accountName: label)

        default:
            // No label or empty label, use empty strings or issuerParam
            let issuer = issuerParam ?? ""
            return (issuer: issuer, accountName: "")
        }
    }


    // MARK: - Helper Methods

    /// Formats the background color for URI inclusion by removing the "#" prefix if present.
    ///
    /// - Parameter backgroundColor: The background color string to format.
    /// - Returns: The formatted background color value, or nil if input is nil.
    public func formatBackgroundColor(_ backgroundColor: String?) -> String? {
        return backgroundColor?.hasPrefix("#") == true
            ? String(backgroundColor!.dropFirst())
            : backgroundColor
    }

    // MARK: - Private Helper Methods

    private func addBase64Padding(_ value: String) -> String {
        let remainder = value.count % 4
        if remainder > 0 {
            return value + String(repeating: "=", count: 4 - remainder)
        }
        return value
    }
}

// MARK: - Error Types

/// Errors that can occur during URI parsing.
public enum UriParseError: Error, LocalizedError, Sendable {
    case issuerMismatch(parameterIssuer: String, labelIssuer: String)
    case malformedURI(String)
    case unsupportedScheme(String)

    public var errorDescription: String? {
        switch self {
        case .issuerMismatch(let parameterIssuer, let labelIssuer):
            return "Issuer parameter (\(parameterIssuer)) doesn't match label issuer (\(labelIssuer))"
        case .malformedURI(let uri):
            return "Malformed URI: \(uri)"
        case .unsupportedScheme(let scheme):
            return "Unsupported URI scheme: \(scheme)"
        }
    }
}
