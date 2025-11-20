//
//  OathAlgorithmHelper.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import CommonCrypto
import CryptoKit
import PingMfaCommons

/// Helper class for OATH algorithm operations, including code generation.
/// Uses iOS CryptoKit and CommonCrypto for cryptographic operations.
///
/// This class provides the core cryptographic functionality for generating
/// TOTP and HOTP codes according to RFC 4226 and RFC 6238 specifications.
enum OathAlgorithmHelper {

    // MARK: - Public Methods

    /// Generate an OTP code for an OATH credential.
    /// - Parameters:
    ///   - credential: The OathCredential to generate code for.
    ///   - timeIntervalSince1970: Optional custom time for TOTP generation. Uses current time if nil.
    /// - Returns: OathCodeInfo containing the code and validity information.
    /// - Throws: `OathError.invalidSecret` if the secret key is invalid.
    /// - Throws: `OathError.codeGenerationFailed` if cryptographic operations fail.
    static func generateCode(for credential: OathCredential, timeIntervalSince1970: TimeInterval? = nil) async throws -> OathCodeInfo {
        switch credential.oathType {
        case .totp:
            return try generateTotpCode(credential, timeIntervalSince1970: timeIntervalSince1970)
        case .hotp:
            return try generateHotpCode(credential)
        }
    }

    
    // MARK: - Private TOTP Methods

    /// Generate a TOTP code for a credential.
    /// - Parameters:
    ///   - credential: The TOTP credential.
    ///   - timeIntervalSince1970: Optional custom time for TOTP generation. Uses current time if nil.
    /// - Returns: OathCodeInfo for TOTP with timing information.
    /// - Throws: `OathError.codeGenerationFailed` if generation fails.
    private static func generateTotpCode(_ credential: OathCredential, timeIntervalSince1970: TimeInterval? = nil) throws -> OathCodeInfo {
        let period = Int64(credential.period)
        let now = Int64(timeIntervalSince1970 ?? Date().timeIntervalSince1970)
        let counter = now / period

        let code = try generateOtpCode(credential, counter: counter)

        // Calculate time remaining in the current period
        let nextPeriodStart = (counter + 1) * period
        let timeRemaining = Int(nextPeriodStart - now)

        return OathCodeInfo.forTotp(
            code: code,
            timeRemaining: timeRemaining,
            totalPeriod: credential.period
        )
    }

    /// Generate a HOTP code for a credential.
    /// - Parameter credential: The HOTP credential.
    /// - Returns: OathCodeInfo for HOTP with counter information.
    /// - Throws: `OathError.codeGenerationFailed` if generation fails.
    private static func generateHotpCode(_ credential: OathCredential) throws -> OathCodeInfo {
        // Use current counter for code generation (RFC 4226 compliance)
        let currentCounter = Int64(credential.counter)
        let code = try generateOtpCode(credential, counter: currentCounter)

        // Return incremented counter for state management
        return OathCodeInfo.forHotp(
            code: code,
            counter: credential.counter + 1
        )
    }

    
    // MARK: - Private Core Methods

    /// Generate the actual OTP code using HMAC.
    /// - Parameters:
    ///   - credential: The OATH credential containing algorithm and secret.
    ///   - counter: The counter value to use for generation.
    /// - Returns: The generated OTP code as a string.
    /// - Throws: `OathError.invalidSecret` if the secret is invalid.
    /// - Throws: `OathError.codeGenerationFailed` if HMAC operations fail.
    private static func generateOtpCode(_ credential: OathCredential, counter: Int64) throws -> String {
        // Validate secret is not empty
        guard !credential.secret.isEmpty else {
            throw OathError.invalidSecret("Secret key cannot be empty")
        }

        // Decode the Base32 secret
        guard let secretData = Data(base32Encoded: credential.secret) else {
            throw OathError.invalidSecret("Invalid Base32 secret key")
        }

        // Ensure decoded secret is not empty
        guard !secretData.isEmpty else {
            throw OathError.invalidSecret("Secret key cannot be empty")
        }

        // Convert counter to 8-byte big-endian data (matching legacy SDK format)
        let counterUInt64 = UInt64(counter)
        let counterData = counterUInt64.bigEndianData

        // Generate HMAC
        let hmacData = try hmac(algorithm: credential.oathAlgorithm, key: secretData, data: counterData)

        // Dynamic truncation (RFC 4226) - matching legacy SDK approach
        var truncated = hmacData.withUnsafeBytes { pointer -> UInt32 in
            let offset = pointer[hmacData.count - 1] & 0x0f
            let truncatedHmac = pointer.baseAddress! + Int(offset)
            return truncatedHmac.bindMemory(to: UInt32.self, capacity: 1).pointee
        }

        // Convert from big-endian and apply mask
        truncated = UInt32(bigEndian: truncated)
        let discard = truncated & 0x7fffffff

        // Generate the final code with appropriate number of digits
        let modulus = UInt32(pow(10, Float(credential.digits)))
        let tmpCode = String(discard % modulus)

        // Add leading zeros if necessary
        if (credential.digits - tmpCode.count) > 0 {
            return String(repeating: "0", count: (credential.digits - tmpCode.count)) + tmpCode
        } else {
            return tmpCode
        }
    }
    

    // MARK: - CryptoKit Implementation

    /// Perform HMAC using CryptoKit.
    /// - Parameters:
    ///   - algorithm: The OATH algorithm.
    ///   - key: The secret key data.
    ///   - data: The data to authenticate.
    /// - Returns: The HMAC result data.
    /// - Throws: `OathError.codeGenerationFailed` if HMAC fails.
    internal static func hmac(algorithm: OathAlgorithm, key: Data, data: Data) throws -> Data {
        let symmetricKey = SymmetricKey(data: key)

        switch algorithm {
        case .sha1:
            let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: data, using: symmetricKey)
            return Data(hmac)
        case .sha256:
            let hmac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
            return Data(hmac)
        case .sha512:
            let hmac = HMAC<SHA512>.authenticationCode(for: data, using: symmetricKey)
            return Data(hmac)
        }
    }
    

    // MARK: - Validation Helpers

    /// Validates that a credential can be used for code generation.
    /// - Parameter credential: The credential to validate.
    /// - Throws: `OathError.invalidSecret` if the secret is invalid.
    /// - Throws: `OathError.invalidParameterValue` if parameters are invalid.
    static func validateCredential(_ credential: OathCredential) throws {
        // Validate the credential itself
        try credential.validate()

        // Additional validation for code generation
        guard !credential.secret.isEmpty else {
            throw OathError.invalidSecret("Secret key cannot be empty")
        }

        // Validate that the secret can be decoded
        guard Data(base32Encoded: credential.secret) != nil else {
            throw OathError.invalidSecret("Secret key is not valid Base32")
        }

        // Validate digits range for code generation
        guard credential.digits >= 4 && credential.digits <= 8 else {
            throw OathError.invalidParameterValue("Digits must be between 4 and 8")
        }

        // Validate period for TOTP
        if credential.oathType == .totp {
            guard credential.period > 0 && credential.period <= 300 else {
                throw OathError.invalidParameterValue("Period must be between 1 and 300 seconds")
            }
        }
    }

    
    // MARK: - Time Helpers

    /// Get the current TOTP time step for a given period.
    /// - Parameter period: The time period in seconds.
    /// - Returns: The current time step.
    static func getCurrentTimeStep(period: Int) -> Int64 {
        let now = Int64(Date().timeIntervalSince1970)
        return now / Int64(period)
    }

    /// Get the time remaining in the current TOTP period.
    /// - Parameter period: The time period in seconds.
    /// - Returns: The time remaining in seconds.
    static func getTimeRemaining(period: Int) -> Int {
        let now = Int64(Date().timeIntervalSince1970)
        let currentStep = now / Int64(period)
        let nextStepStart = (currentStep + 1) * Int64(period)
        return Int(nextStepStart - now)
    }

    /// Calculate the progress through the current TOTP period.
    /// - Parameter period: The time period in seconds.
    /// - Returns: A value from 0.0 to 1.0 indicating progress through the period.
    static func getTotpProgress(period: Int) -> Double {
        let timeRemaining = getTimeRemaining(period: period)
        return 1.0 - (Double(timeRemaining) / Double(period))
    }
}


// MARK: - UInt64 Extension

/// Extension for converting UInt64 to Data with big-endian byte order (required by RFC 4226/6238)
extension UInt64 {
    /// Data converted from UInt64 in big-endian format
    var bigEndianData: Data {
        var bigEndianValue = self.bigEndian
        return withUnsafeBytes(of: &bigEndianValue) { Data($0) }
    }
}
