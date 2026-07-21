//
//  PasswordCollector.swift
//  PingDavinci
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingDavinciPlugin

/// Class representing a PASSWORD Type.
/// This class inherits from the `ValidatedCollector` class and implements the `Closeable` and `Collector` protocols.
/// It is used to collect password data.
public class PasswordCollector: ValidatedCollector, ContinueNodeAware, Closeable, @unchecked Sendable {
    /// The continue node for the DaVinci flow.
    /// Declared `weak` to break the retain cycle: `ContinueNode → PasswordCollector → ContinueNode`.
    public weak var continueNode: ContinueNode?
    /// Caches the decoded password policy so it's only decoded once.
    private var cachedPasswordPolicy: PasswordPolicy?
    /// A flag to determine whether to clear the password or not after submission.
    public var clearPassword: Bool = true
    
    /// Initializes a new instance of `PasswordCollector`.
    /// Extracts the password policy from the field-level JSON if present.
    /// - Parameter json: The JSON dictionary for this field component.
    public required init(with json: [String: Any]) {
        super.init(with: json)
        
        // Extract passwordPolicy from the field-level JSON (component scope)
        if let policyDict = json[Constants.passwordPolicy] as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: policyDict, options: []) {
                cachedPasswordPolicy = try? JSONDecoder().decode(PasswordPolicy.self, from: data)
            }
        }
    }
    
    /// Overrides the close function from the Closeable protocol.
    /// It is used to clear the value of the password field when the collector is closed.
    public func close() {
        if clearPassword {
            value = ""
        }
    }
    
    /// Method to retrieve the password policy, if available.
    /// Checks the field-level (component scope) first, then falls back to the global scope
    /// for backward compatibility with older server responses.
    /// - Returns: The password policy, if available.
    public func passwordPolicy() -> PasswordPolicy? {
        if cachedPasswordPolicy == nil {
            // Fallback: check the global scope (top-level input) for backward compatibility
            if let policyDict = continueNode?.input[Constants.passwordPolicy] as? [String: Any] {
                if let data = try? JSONSerialization.data(withJSONObject: policyDict, options: []) {
                    cachedPasswordPolicy = try? JSONDecoder().decode(PasswordPolicy.self, from: data)
                }
            }
        }
        return cachedPasswordPolicy
    }
    
    public override func validate() -> [ValidationError] {
        var errors = super.validate()
        
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
            
            // 4. Check minimum required characters
            for (chars, minCount) in policy.minCharacters {
                let foundCount = value.filter { chars.contains($0) }.count
                if foundCount < minCount {
                    errors.append(.minCharacters(character: chars, min: minCount))
                }
            }
        }
        
        return errors
    }
}
