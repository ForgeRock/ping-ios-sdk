//
//  PasswordCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate

/// Class representing a PASSWORD Type.
/// This class inherits from the `ValidatedCollector` class and implements the `Closeable` and `Collector` protocols.
/// It is used to collect password data.
public class PasswordCollector: ValidatedCollector, ContinueNodeAware, Closeable, @unchecked Sendable {
    /// The continue node for the DaVinci flow.
    public var continueNode: ContinueNode?
    /// Caches the decoded password policy so it’s only decoded once.
    private var cachedPasswordPolicy: PasswordPolicy?
    /// A flag to determine whether to clear the password or not after submission.
    public var clearPassword: Bool = true
    
    /// Overrides the close function from the Closeable protocol.
    /// It is used to clear the value of the password field when the collector is closed.
    public func close() {
        if clearPassword {
            value = ""
        }
    }
    
    /// Method to retrieve the password policy, if available.
    /// - Returns: The password policy, if available.
    public func passwordPolicy() -> PasswordPolicy? {
        if cachedPasswordPolicy == nil {
            // If there's a dictionary under "passwordPolicy"
            if let policyDict = continueNode?.input[Constants.passwordPolicy] as? [String: Any] {
                
                guard let data = try? JSONSerialization.data(withJSONObject: policyDict, options: []) else { return nil }
                return try? JSONDecoder().decode(PasswordPolicy.self, from: data)
            }
        }
        return cachedPasswordPolicy
    }
    
    public override func validate() -> [ValidationError] {
        var errors = super.validate()
        
        // If we have a password policy, check additional constraints
        if let policy = passwordPolicy() {
            // 1. Check length range
            if !(policy.length.min...policy.length.max).contains(value.count) {
                errors.append(.invalidLength(min: policy.length.min, max: policy.length.max))
            }
            
            // 2. Check minimum unique characters
            let uniqueCount = Set(value).count
            if uniqueCount < policy.minUniqueCharacters {
                errors.append(.uniqueCharacter(min: policy.minUniqueCharacters))
            }
            
            // 3. Check maximum repeated characters
            let characterCounts = value.reduce(into: [Character: Int]()) { counts, char in
                counts[char, default: 0] += 1
            }
            let maxRepeated = characterCounts.values.max() ?? 0
            if maxRepeated > policy.maxRepeatedCharacters {
                errors.append(.maxRepeat(max: policy.maxRepeatedCharacters))
            }
            
            // 4. Check minimum required characters (e.g. "digits" -> 2)
            for (chars, minCount) in policy.minCharacters {
                // `chars` might be a string of characters, or some other token
                // We count how many characters in `value` are in `chars`
                let foundCount = value.filter { chars.contains($0) }.count
                if foundCount < minCount {
                    errors.append(.minCharacters(character: chars, min: minCount))
                }
            }
        }
        
        return errors
    }
}
