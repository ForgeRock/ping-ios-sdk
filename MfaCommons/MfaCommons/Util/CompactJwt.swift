//
//  JwtUtils.swift
//  PingMfaCommons
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CryptoKit

/// CompactJwt is a utility class responsible to perform simple, and specific JWT operation within MFA modules for JWT-related operations.
/// Provides methods for generating and validating JWTs using the HS256 algorithm.
public final class CompactJwt: Sendable {

    private init() {} // Utility class - prevent instantiation

    
    // MARK: - JWT Generation

    /// Signs given claims using the HS256 algorithm.
    ///
    /// - Parameters:
    ///   - base64Secret: The base64-encoded secret key.
    ///   - claims: The claims to include in the JWT.
    /// - Returns: The JWT string.
    /// - Throws: `JwtError.invalidSecret` if the secret is empty or invalid.
    ///           `JwtError.signingFailed` if there is an error signing the JWT.
    public static func signJwtClaims(base64Secret: String, claims: [String: Any]) throws -> String {
        // Validate secret
        guard !base64Secret.isEmpty else {
            throw JwtError.invalidSecret("Secret cannot be empty")
        }

        guard let secretData = Data(base64Encoded: base64Secret) else {
            throw JwtError.invalidSecret("Invalid base64 secret")
        }

        do {
            // Create JWT header
            let header = [
                "typ": "JWT",
                "alg": "HS256"
            ]

            // Encode header and payload
            let encodedHeader = try encodeToBase64URL(header)
            let encodedPayload = try encodeToBase64URL(claims)

            // Create signature data
            let signingInput = "\(encodedHeader).\(encodedPayload)"
            guard let signingData = signingInput.data(using: .utf8) else {
                throw JwtError.signingFailed("Cannot convert signing input to data")
            }

            // Generate HMAC signature
            let key = SymmetricKey(data: secretData)
            let signature = HMAC<SHA256>.authenticationCode(for: signingData, using: key)
            let signatureData = Data(signature)
            let encodedSignature = signatureData.base64URLEncodedString()

            return "\(encodedHeader).\(encodedPayload).\(encodedSignature)"

        } catch let error as JwtError {
            throw error
        } catch {
            throw JwtError.signingFailed("Failed to generate JWT: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - JWT Validation

    /// Checks if a string is a valid JWT and contains the required fields in its payload.
    ///
    /// - Parameters:
    ///   - jwt: The JWT string to validate.
    ///   - requiredFields: An array of field names to check in the payload.
    /// - Returns: `true` if the JWT is valid and contains all required fields, `false` otherwise.
    public static func canParseJwt(_ jwt: String, requiredFields: [String] = []) -> Bool {
        // Parse the JWT structure
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            return false
        }

        // Decode the payload (second part of the JWT)
        let payloadString = String(parts[1])
        guard let payloadData = Base64.decodeBase64UrlToData(payloadString),
              let payloadJson = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return false
        }

        // Check for required fields if provided
        if !requiredFields.isEmpty {
            for field in requiredFields {
                if payloadJson[field] == nil {
                    return false
                }
            }
        }

        return true
    }

    /// Verifies the signature of a JWT using the provided secret.
    ///
    /// - Parameters:
    ///   - jwt: The JWT string to verify.
    ///   - base64Secret: The base64-encoded secret key used for verification.
    /// - Returns: `true` if the signature is valid, `false` otherwise.
    /// - Throws: `JwtError.invalidSecret` if the secret is empty or invalid.
    ///           `JwtError.invalidFormat` if the JWT format is invalid.
    ///           `JwtError.signingFailed` if there is an error during verification.
    public static func verifyJwtSignature(_ jwt: String, base64Secret: String) throws -> Bool {
        // Validate secret
        guard !base64Secret.isEmpty else {
            throw JwtError.invalidSecret("Secret cannot be empty")
        }
        
        guard let secretData = Data(base64Encoded: base64Secret) else {
            throw JwtError.invalidSecret("Invalid base64 secret")
        }
        
        // Parse the JWT structure
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw JwtError.invalidFormat("Invalid JWT format - must have 3 parts")
        }
        
        let headerString = String(parts[0])
        let payloadString = String(parts[1])
        let signatureString = String(parts[2])
        
        // Parse the header
        guard let headerData = Base64.decodeBase64UrlToData(headerString),
                let headerJson = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any] else {
            throw JwtError.failToConvertData("Unsupported JWT algorithm - only HS256 is supported")
        }
        
        // Ensure the algorithm is HS256
        guard let alg = headerJson["alg"] as? String, alg == "HS256" else {
            throw JwtError.unsupportedAlgorithm("Unsupported JWT algorithm - only HS256 is supported")
        }
        
        // Verify the signature
        do {
            // Recreate the signing input
            let signingInput = "\(headerString).\(payloadString)"
            guard let signingData = signingInput.data(using: .utf8) else {
                throw JwtError.signingFailed("Cannot convert signing input to data")
            }
            
            // Generate expected signature using the same method as generation
            let key = SymmetricKey(data: secretData)
            let expectedSignature = HMAC<SHA256>.authenticationCode(for: signingData, using: key)
            let expectedSignatureData = Data(expectedSignature)
            let expectedEncodedSignature = expectedSignatureData.base64URLEncodedString()
            
            // Decode the provided signature for comparison
            guard let providedSignatureData = Base64.decodeBase64UrlToData(signatureString) else {
                throw JwtError.signingFailed("Cannot decode provided signature")
            }
            
            // Compare signatures using constant-time comparison
            return expectedSignatureData.count == providedSignatureData.count &&
                   expectedSignatureData.withUnsafeBytes { expectedBytes in
                       providedSignatureData.withUnsafeBytes { providedBytes in
                           var result = 0
                           for i in 0..<expectedBytes.count {
                               result |= Int(expectedBytes[i]) ^ Int(providedBytes[i])
                           }
                           return result == 0
                       }
                   }
            
        } catch let error as JwtError {
            throw error
        } catch {
            throw JwtError.signingFailed("Failed to verify JWT signature: \(error.localizedDescription)")
        }
    }

    
    // MARK: - JWT Parsing

    /// Parses a JWT string and extracts its payload claims.
    ///
    /// - Parameter jwt: The JWT string to parse.
    /// - Returns: A dictionary containing the payload claims.
    /// - Throws: `JwtError.invalidFormat` if the JWT format is invalid.
    ///          `JwtError.invalidPayload` if the payload cannot be parsed.
    public static func parseJwtClaims(_ jwt: String) throws -> [String: Any] {
        // Parse the JWT structure
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else {
            throw JwtError.invalidFormat("Invalid JWT format - must have 3 parts")
        }

        // Decode the payload (second part of the JWT)
        let payloadString = String(parts[1])
        guard let payloadData = Base64.decodeBase64UrlToData(payloadString) else {
            throw JwtError.invalidPayload("Cannot decode JWT payload")
        }

        do {
            guard let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
                throw JwtError.invalidPayload("Payload is not a valid JSON object")
            }
            return payloadJson
        } catch {
            throw JwtError.invalidPayload("Cannot parse JWT payload JSON: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helper Methods

    private static func encodeToBase64URL(_ object: Any) throws -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object)
            return jsonData.base64URLEncodedString()
        } catch {
            throw JwtError.signingFailed("Cannot encode object to JSON: \(error.localizedDescription)")
        }
    }
    
}


// MARK: - JWT Error Types

/// Errors that can occur during JWT operations.
public enum JwtError: Error, LocalizedError, Sendable {
    case invalidSecret(String)
    case invalidFormat(String)
    case invalidPayload(String)
    case signingFailed(String)
    case failToConvertData(String)
    case unsupportedAlgorithm(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSecret(let message):
            return "Invalid JWT secret: \(message)"
        case .invalidFormat(let message):
            return "Invalid JWT format: \(message)"
        case .invalidPayload(let message):
            return "Invalid JWT payload: \(message)"
        case .signingFailed(let message):
            return "JWT signing failed: \(message)"
        case .failToConvertData(let message):
            return "Failed to convert data: \(message)"
        case .unsupportedAlgorithm(let message):
            return "Unsupported JWT algorithm: \(message)"
        }
    }
}
