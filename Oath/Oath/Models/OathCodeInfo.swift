//
//  OathCodeInfo.swift
//  PingOath
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Contains OTP code information, including the actual code and validity details.
///
/// This class provides comprehensive information about a generated OTP code,
/// including timing information for TOTP codes and counter information for HOTP codes.
public struct OathCodeInfo: Codable, Sendable {

    // MARK: - Properties
    
    /// The generated OTP code.
    public let code: String

    /// For TOTP, the time remaining in seconds before the code expires.
    /// For HOTP, this will be -1.
    public let timeRemaining: Int

    /// For HOTP, the current counter value after code generation.
    /// For TOTP, this will be -1.
    public let counter: Int

    /// For TOTP, a value from 0.0 to 1.0 indicating progress through the time window.
    /// For HOTP, this will be 0.0.
    public let progress: Double

    /// For TOTP, the total validity period in seconds.
    /// For HOTP, this will be 0.
    public let totalPeriod: Int

    
    // MARK: - Initializers

    /// Private initializer to ensure proper construction through factory methods.
    private init(
        code: String,
        timeRemaining: Int,
        counter: Int,
        progress: Double,
        totalPeriod: Int
    ) {
        self.code = code
        self.timeRemaining = timeRemaining
        self.counter = counter
        self.progress = progress
        self.totalPeriod = totalPeriod
    }

    
    // MARK: - Factory Methods

    /// Creates an instance for a TOTP code.
    /// - Parameters:
    ///   - code: The generated OTP code.
    ///   - timeRemaining: The time remaining in seconds before the code expires.
    ///   - totalPeriod: The total validity period in seconds.
    /// - Returns: An OathCodeInfo instance configured for TOTP.
    public static func forTotp(
        code: String,
        timeRemaining: Int,
        totalPeriod: Int
    ) -> OathCodeInfo {
        let progress = totalPeriod > 0 ? 1.0 - (Double(timeRemaining) / Double(totalPeriod)) : 0.0
        return OathCodeInfo(
            code: code,
            timeRemaining: timeRemaining,
            counter: -1,
            progress: progress,
            totalPeriod: totalPeriod
        )
    }

    /// Creates an instance for a HOTP code.
    /// - Parameters:
    ///   - code: The generated OTP code.
    ///   - counter: The counter value after code generation.
    /// - Returns: An OathCodeInfo instance configured for HOTP.
    public static func forHotp(
        code: String,
        counter: Int
    ) -> OathCodeInfo {
        return OathCodeInfo(
            code: code,
            timeRemaining: -1,
            counter: counter,
            progress: 0.0,
            totalPeriod: 0
        )
    }

    
    // MARK: - JSON Serialization

    /// Converts this code info to a JSON string representation.
    ///
    /// This is a convenience method for cross-platform API consistency.
    /// You can also use Swift's standard `JSONEncoder` directly:
    /// ```swift
    /// let encoder = JSONEncoder()
    /// let data = try encoder.encode(codeInfo)
    /// let jsonString = String(data: data, encoding: .utf8)
    /// ```
    ///
    /// - Returns: A JSON string representing this code info.
    /// - Throws: `EncodingError` if serialization fails.
    public func toJson() throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Creates an OathCodeInfo from a JSON string.
    ///
    /// This is a convenience method for cross-platform API consistency.
    /// You can also use Swift's standard `JSONDecoder` directly:
    /// ```swift
    /// let decoder = JSONDecoder()
    /// let codeInfo = try decoder.decode(OathCodeInfo.self, from: jsonData)
    /// ```
    ///
    /// - Parameter jsonString: The JSON string to parse.
    /// - Returns: An OathCodeInfo instance.
    /// - Throws: `DecodingError` if the JSON is invalid.
    public static func fromJson(_ jsonString: String) throws -> OathCodeInfo {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF-8 string")
            )
        }
        let decoder = JSONDecoder()
        return try decoder.decode(OathCodeInfo.self, from: data)
    }
}
