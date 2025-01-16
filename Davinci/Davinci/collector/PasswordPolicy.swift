//
//  PasswordPolicy.swift
//  PingDavinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

/// A struct representing a password policy
/// Conforms to `Codable` for JSON encoding/decoding.
public struct PasswordPolicy: Codable {
    /// A name identifying this password policy.
    public let name: String
    /// A human-readable description of the policy.
    public let description: String
    /// Whether profile data is excluded
    public let excludesProfileData: Bool
    /// Whether new passwords must not be similar to the current password.
    public let notSimilarToCurrent: Bool
    /// Whether commonly used passwords are excluded.
    public let excludesCommonlyUsed: Bool
    /// The maximum number of days a password is valid before it must be changed.
    public let maxAgeDays: Int
    /// The minimum number of days a password must be used before it can be changed.
    public let minAgeDays: Int
    /// The maximum number of repeated characters allowed in a password.
    public let maxRepeatedCharacters: Int
    /// The minimum number of unique characters required in a password.
    public let minUniqueCharacters: Int
    /// A nested `History` struct specifying password history restrictions, if any.
    public let history: History?
    /// A nested `Lockout` struct specifying lockout rules, if any.
    public let lockout: Lockout?
    /// A nested `Length` struct specifying minimum and maximum length constraints.
    public let length: Length
    /// A dictionary specifying minimum required counts for certain character types
    public let minCharacters: [String: Int]
    /// An integer denoting how many users or “population” this policy applies to
    public let populationCount: Int
    /// The creation timestamp of this policy
    public let createdAt: String
    /// The last update timestamp of this policy
    public let updatedAt: String
    /// Indicates whether this policy is the default one.
    public let `default`: Bool
    
    /// Initializes a new `PasswordPolicy` instance.
    /// - Parameters:
    ///   - name: A name identifying this password policy.
    ///   - description: A human-readable description of the policy.
    ///   - excludesProfileData: Whether profile data is excluded
    ///   - notSimilarToCurrent: Whether new passwords must not be similar to the current password.
    ///   - excludesCommonlyUsed: Whether commonly used passwords are excluded.
    ///   - maxAgeDays: he maximum number of days a password is valid before it must be changed.
    ///   - minAgeDays: The minimum number of days a password must be used before it can be changed.
    ///   - maxRepeatedCharacters: The maximum number of repeated characters allowed in a password.
    ///   - minUniqueCharacters: The minimum number of unique characters required in a password.
    ///   - history: `History` struct specifying password history restrictions, if any.
    ///   - lockout: `Lockout` struct specifying lockout rules, if any.
    ///   - length: `Length` struct specifying minimum and maximum length constraints.
    ///   - minCharacters: A dictionary specifying minimum required counts for certain character types
    ///   - populationCount: An integer denoting how many users or “population” this policy applies to
    ///   - createdAt: The creation timestamp of this policy
    ///   - updatedAt: The last update timestamp of this policy
    ///   - `default`: Indicates whether this policy is the default one.
    public init(
        name: String = "",
        description: String = "",
        excludesProfileData: Bool = false,
        notSimilarToCurrent: Bool = false,
        excludesCommonlyUsed: Bool = false,
        maxAgeDays: Int = 0,
        minAgeDays: Int = 0,
        maxRepeatedCharacters: Int = Int.max,
        minUniqueCharacters: Int = 0,
        history: History? = nil,
        lockout: Lockout? = nil,
        length: Length = Length(min: 0, max: Int.max),
        minCharacters: [String: Int] = [:],
        populationCount: Int = 0,
        createdAt: String = "",
        updatedAt: String = "",
        `default`: Bool = false
    ) {
        self.name = name
        self.description = description
        self.excludesProfileData = excludesProfileData
        self.notSimilarToCurrent = notSimilarToCurrent
        self.excludesCommonlyUsed = excludesCommonlyUsed
        self.maxAgeDays = maxAgeDays
        self.minAgeDays = minAgeDays
        self.maxRepeatedCharacters = maxRepeatedCharacters
        self.minUniqueCharacters = minUniqueCharacters
        self.history = history
        self.lockout = lockout
        self.length = length
        self.minCharacters = minCharacters
        self.populationCount = populationCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.`default` = `default`
    }
}

/// A struct representing the password policy history.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct History: Codable {
    /// The number of recent passwords to keep in history to disallow reuse.
    public let count: Int
    /// The retention period (in days) for password history entries.
    public let retentionDays: Int
    
    /// Initializes a new `History` configuration.
    /// - Parameters:
    ///   - count: How many passwords to remember (disallowing reuse).
    ///   - retentionDays: How many days a password remains in the history.
    public init(count: Int, retentionDays: Int) {
        self.count = count
        self.retentionDays = retentionDays
    }
}

/// A struct representing the password policy lockout rules.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct Lockout: Codable {
    /// The number of failed login attempts that trigger a lockout.
    public let failureCount: Int
    /// The lockout duration in seconds once the failure threshold is reached.
    public let durationSeconds: Int
    
    /// Initializes a new `Lockout` configuration.
    /// - Parameters:
    ///   - failureCount: Number of failed attempts before lockout.
    ///   - durationSeconds: Lockout duration in seconds.
    public init(failureCount: Int, durationSeconds: Int) {
        self.failureCount = failureCount
        self.durationSeconds = durationSeconds
    }
}

/// A struct representing the min/max length constraints.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct Length: Codable {
    /// The minimum required length for a password.
    public let min: Int
    /// The maximum allowed length for a password.
    public let max: Int
    
    /// Initializes a new `Length` configuration.
    /// - Parameters:
    ///   - min: The minimum required password length.
    ///   - max: The maximum allowed password length.
    public init(min: Int = 0, max: Int = Int.max) {
        self.min = min
        self.max = max
    }
}

