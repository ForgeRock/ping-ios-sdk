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
import Security

// MARK: - SecKey to JWK Conversion

enum SecKeyToJWKError: Error, LocalizedError {
    case notECKey
    case externalRepresentationFailed
    case invalidECKeyDataFormat
    case unsupportedKeySize

    var errorDescription: String? {
        switch self {
        case .notECKey:
            return "The provided SecKey is not an Elliptic Curve key."
        case .externalRepresentationFailed:
            return "Failed to get external representation of the SecKey."
        case .invalidECKeyDataFormat:
            return "Invalid format for the external representation of the EC key."
        case .unsupportedKeySize:
            return "Unsupported elliptic curve key size."
        }
    }
}

/// CompactJwt is a utility class responsible to perform simple, and specific JWT operation within MFA modules for JWT-related operations.
/// Provides methods for generating and validating JWTs using the HS256 algorithm.
public final class CompactJwt: Sendable {

    private init() {} // Utility class - prevent instantiation

    // MARK: - ASN.1 Parsing Helpers

    enum ASN1Error: Error {
        case invalidFormat
        case unexpectedTag
        case lengthMismatch
    }

    struct ASN1 {
        static func parse(data: Data) throws -> (tag: UInt8, length: Int, value: Data, remainder: Data) {
            var offset = 0
            
            guard offset < data.count else { throw ASN1Error.invalidFormat }
            let tag = data[offset]
            offset += 1
            
            guard offset < data.count else { throw ASN1Error.invalidFormat }
            var length = Int(data[offset])
            offset += 1
            
            if length > 0x7F { // Long form length
                let lengthBytesCount = Int(length & 0x7F)
                guard offset + lengthBytesCount <= data.count else { throw ASN1Error.invalidFormat }
                length = 0
                for i in 0..<lengthBytesCount {
                    length = (length << 8) | Int(data[offset + i])
                }
                offset += lengthBytesCount
            }
            
            guard offset + length <= data.count else { throw ASN1Error.lengthMismatch }
            let value = data.subdata(in: offset..<(offset + length))
            let remainder = data.subdata(in: (offset + length)..<data.count)
            
            return (tag, length, value, remainder)
        }
        
        static func readInteger(from data: Data) throws -> (Data, Data) {
            let (tag, _, value, remainder) = try parse(data: data)
            guard tag == 0x02 else { throw ASN1Error.unexpectedTag } // 0x02 is INTEGER tag
            return (value, remainder)
        }
        
        static func readSequence(from data: Data) throws -> (Data, Data) {
            let (tag, _, value, remainder) = try parse(data: data)
            guard tag == 0x30 else { throw ASN1Error.unexpectedTag } // 0x30 is SEQUENCE tag
            return (value, remainder)
        }
        
        static func toRaw(data: Data, length: Int) -> Data {
            var raw = data
            if raw.count > length {
                raw = raw.subdata(in: (raw.count - length)..<raw.count)
            } else if raw.count < length {
                let padding = Data(repeating: 0x00, count: length - raw.count)
                raw = padding + raw
            }
            return raw
        }
    }

    /// Converts an EC public SecKey to its JWK (JSON Web Key) components.
    ///
    /// - Parameter publicKey: The `SecKey` object representing the EC public key.
    /// - Parameter kid: The key ID to include in the JWK.
    /// - Returns: A dictionary representing the JWK components, or `nil` if the conversion fails.
    private static func secKeyToJwkEC(publicKey: SecKey, kid: String) throws -> [String: Any] {
        // 1. Get key attributes to determine key type and size
        guard let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any] else {
            throw SecKeyToJWKError.externalRepresentationFailed
        }

        guard let keyType = attributes[kSecAttrKeyType] as? String,
              (keyType == kSecAttrKeyTypeEC as String || keyType == kSecAttrKeyTypeECSECPrimeRandom as String) else {
            throw SecKeyToJWKError.notECKey
        }

        guard let keySizeInBits = attributes[kSecAttrKeySizeInBits] as? Int else {
            throw SecKeyToJWKError.unsupportedKeySize
        }

        let crv: String
        let coordinateLength: Int // Length in bytes for x and y coordinates
        switch keySizeInBits {
        case 256:
            crv = "P-256"
            coordinateLength = 32
        case 384:
            crv = "P-384"
            coordinateLength = 48
        case 521:
            crv = "P-521"
            coordinateLength = 66 // P-521 uses 66 bytes for coordinates
        default:
            throw SecKeyToJWKError.unsupportedKeySize
        }

        // 2. Get the external representation of the public key
        var error: Unmanaged<CFError>?
        guard let externalRepresentation = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw SecKeyToJWKError.externalRepresentationFailed
        }

        // 3. Parse the external representation (ANSI X9.63 format: 04 || X || Y)
        // Expected format: 0x04 followed by X and Y coordinates
        let expectedLength = 1 + (2 * coordinateLength)
        guard externalRepresentation.count == expectedLength,
              externalRepresentation.first == 0x04 else {
            throw SecKeyToJWKError.invalidECKeyDataFormat
        }

        let xCoordinateData = externalRepresentation.subdata(in: 1..<(1 + coordinateLength))
        let yCoordinateData = externalRepresentation.subdata(in: (1 + coordinateLength)..<expectedLength)

        // 4. Base64URL encode x and y coordinates
        let x = xCoordinateData.base64URLEncodedString()
        let y = yCoordinateData.base64URLEncodedString()

        // 5. Construct the JWK dictionary
        // Determine the algorithm name based on the curve
        let algName: String
        switch crv {
        case "P-256":
            algName = "ES256"
        case "P-384":
            algName = "ES384"
        case "P-521":
            algName = "ES512"
        default:
            algName = "ES256" // Fallback, though this shouldn't be reached
        }
        
        let jwk: [String: Any] = [
            "crv": crv,
            "kty": "EC",
            "use": "sig",
            "y": y,
            "kid": kid,
            "x": x,
            "alg": algName
        ]

        return jwk
    }

    
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

    /// Signs given claims using an asymmetric key algorithm.
    ///
    /// - Parameters:
    ///   - claims: The claims to include in the JWT.
    ///   - privateKey: The private key used to sign the JWT.
    ///   - algorithm: The algorithm to use for signing (e.g., ES256).
    ///   - kid: The key ID to include in the JWT header.
    /// - Returns: The JWT string.
    /// - Throws: `JwtError.signingFailed` if there is an error signing the JWT.
    public static func sign(claims: [String: Any], privateKey: SecKey, publicKey: SecKey?, algorithm: SecKeyAlgorithm, kid: String) throws -> String {
        // Determine the algorithm name based on the SecKeyAlgorithm
        let algName: String
        switch algorithm {
        case .ecdsaSignatureMessageX962SHA256:
            algName = "ES256"
        case .ecdsaSignatureMessageX962SHA384:
            algName = "ES384"
        case .ecdsaSignatureMessageX962SHA512:
            algName = "ES512"
        default:
            throw JwtError.unsupportedAlgorithm("Unsupported algorithm: \(algorithm)")
        }
        
        var header: [String: Any] = [
            "typ": "JWS",
            "alg": algName,
            "kid": kid
        ]
        
        if let publicKey = publicKey {
            let jwk = try secKeyToJwkEC(publicKey: publicKey, kid: kid)
            header["jwk"] = jwk
        }
        
        let encodedHeader = try encodeToBase64URL(header)
        let encodedPayload = try encodeToBase64URL(claims)
        
        let signingInput = "\(encodedHeader).\(encodedPayload)"
        guard let signingData = signingInput.data(using: .utf8) else {
            throw JwtError.signingFailed("Cannot convert signing input to data")
        }
        
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, signingData as CFData, &error) else {
            throw JwtError.signingFailed("Failed to sign JWT: \(error!.takeRetainedValue().localizedDescription)")
        }
        
        // Unpack BER encoded ASN.1 signature to raw format as specified for JWS
        let ecSignatureTLV = signature as Data
        let (sequenceValue, _) = try ASN1.readSequence(from: ecSignatureTLV)
        let (rValue, rRemainder) = try ASN1.readInteger(from: sequenceValue)
        let (sValue, _) = try ASN1.readInteger(from: rRemainder)
        
        // Determine coordinate length based on algorithm (ES256 -> P-256 -> 32 bytes)
        let coordinateLength: Int
        switch algorithm {
        case .ecdsaSignatureMessageX962SHA256:
            coordinateLength = 32
        case .ecdsaSignatureMessageX962SHA384:
            coordinateLength = 48
        case .ecdsaSignatureMessageX962SHA512:
            coordinateLength = 66 // P-521 uses 66 bytes for coordinates
        default:
            throw JwtError.unsupportedAlgorithm("Unsupported EC algorithm for signature unpacking")
        }
        
        let fixlenR = ASN1.toRaw(data: rValue, length: coordinateLength)
        let fixlenS = ASN1.toRaw(data: sValue, length: coordinateLength)
        
        let rawSignature = fixlenR + fixlenS
        
        let encodedSignature = rawSignature.base64URLEncodedString()
        
        return "\(encodedHeader).\(encodedPayload).\(encodedSignature)"
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
