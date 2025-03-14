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
public struct PasswordPolicy: Codable, Sendable {
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
    
    enum CodingKeys: String, CodingKey {
        case name, description, excludesProfileData, notSimilarToCurrent, excludesCommonlyUsed
        case maxAgeDays, minAgeDays, maxRepeatedCharacters, minUniqueCharacters
        case history, lockout, length, minCharacters, populationCount
        case createdAt, updatedAt, `default`
    }
    
    /// Initializes a new `PasswordPolicy` instance from the provided decoder.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        excludesProfileData = try container.decodeIfPresent(Bool.self, forKey: .excludesProfileData) ?? false
        notSimilarToCurrent = try container.decodeIfPresent(Bool.self, forKey: .notSimilarToCurrent) ?? false
        excludesCommonlyUsed = try container.decodeIfPresent(Bool.self, forKey: .excludesCommonlyUsed) ?? false
        maxAgeDays = try container.decodeIfPresent(Int.self, forKey: .maxAgeDays) ?? 0
        minAgeDays = try container.decodeIfPresent(Int.self, forKey: .minAgeDays) ?? 0
        maxRepeatedCharacters = try container.decodeIfPresent(Int.self, forKey: .maxRepeatedCharacters) ?? Int.max
        minUniqueCharacters = try container.decodeIfPresent(Int.self, forKey: .minUniqueCharacters) ?? 0
        history = try container.decodeIfPresent(History.self, forKey: .history)
        lockout = try container.decodeIfPresent(Lockout.self, forKey: .lockout)
        length = try container.decodeIfPresent(Length.self, forKey: .length) ?? Length()
        minCharacters = try container.decodeIfPresent([String: Int].self, forKey: .minCharacters) ?? [:]
        populationCount = try container.decodeIfPresent(Int.self, forKey: .populationCount) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt) ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        `default` = try container.decodeIfPresent(Bool.self, forKey: .default) ?? false
    }
}

/// A struct representing the password policy history.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct History: Codable, Sendable {
    /// The number of recent passwords to keep in history to disallow reuse.
    public let count: Int
    /// The retention period (in days) for password history entries.
    public let retentionDays: Int
    
    enum CodingKeys: String, CodingKey {
        case count, retentionDays
    }
    
    /// Initializes a new `History` instance.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        retentionDays = try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 0
    }
}

/// A struct representing the password policy lockout rules.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct Lockout: Codable, Sendable {
    /// The number of failed login attempts that trigger a lockout.
    public let failureCount: Int
    /// The lockout duration in seconds once the failure threshold is reached.
    public let durationSeconds: Int
    
    enum CodingKeys: String, CodingKey {
        case failureCount, durationSeconds
    }
    
    /// Initializes a new `Lockout` instance.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        failureCount = try container.decodeIfPresent(Int.self, forKey: .failureCount) ?? 0
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0
    }
}

/// A struct representing the min/max length constraints.
/// Conforms to `Codable` for JSON encoding/decoding.
public struct Length: Codable, Sendable {
    /// The minimum required length for a password.
    public let min: Int
    /// The maximum allowed length for a password.
    public let max: Int
    
    enum CodingKeys: String, CodingKey {
        case min, max
    }
    
    /// Initializes a new `Length` instance.
    /// - Parameter decoder: The decoder to read data from.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        min = try container.decodeIfPresent(Int.self, forKey: .min) ?? 0
        max = try container.decodeIfPresent(Int.self, forKey: .max) ?? Int.max
    }
    
    /// Initializes a new `Length` configuration.
    /// - Parameters:
    ///   - min: The minimum required password length.
    ///   - max: The maximum allowed password length.
    public init(min: Int = 0, max: Int = Int.max) {
        self.min = min
        self.max = max
    }
}

