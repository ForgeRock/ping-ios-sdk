//
//  AbstractValidatedCallback.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Callback that accepts user input often need to validate that input either on the client side, the server side
/// or both. Such callback should extend this base class.
open class AbstractValidatedCallback: AbstractCallback, ObservableObject, @unchecked Sendable {

    /// The prompt message displayed to the user.
    private(set) public var prompt: String = ""
    /// Policies as in JSON format that contains validation rules and details for the input
    private(set) public var policies: [String: Any] = [:]
    /// An array of FailedPolicy for user input validation
    private(set) public var failedPolicies: [FailedPolicy] = []
    /// Boolean indicator when it's set to `true`, `Node` does not advance even if all validations are passed; only works when validation is enabled in AM's Node
    public var validateOnly: Bool = false

    //  MARK: - Init

    /// Initializes a new instance of `AbstractValidatedCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.prompt:
            if let stringValue = value as? String {
                self.prompt = stringValue
            }
        case JourneyConstants.policies:
            if let dictValue = value as? [String: Any] {
                self.policies = dictValue
            }
        case JourneyConstants.validateOnly:
            if let boolValue = value as? Bool {
                self.validateOnly = boolValue
            }
        case JourneyConstants.failedPolicies:
            if let arrayValue = value as? [String] {
                self.failedPolicies = []
                for policy in arrayValue {
                    if let strData = policy.data(using: .utf8) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: strData, options: []) as? [String: Any] {
                                self.failedPolicies.append(try FailedPolicy(self.prompt, json))
                            }
                        } catch {
                            // Handle parsing error silently
                        }
                    }
                }
            }
        default:
            break
        }
    }
}

/// FailedPolicy that describes reason, and additional information for user input validation failure
public class FailedPolicy {

    /// Failed policy parameter that explains specific requirement, and reason for failure
    public var params: [String: Any]?
    /// Policy requirement that states specific policy that failed
    public var policyRequirement: String

    /// Constructs FailedPolicy object with property name, and raw JSON response from OpenAM
    ///
    /// - Parameters:
    ///   - propertyName: Property name of failed policy; 'prompt' property in Callback object
    ///   - json: Raw JSON response from OpenAM for a specific failed policy
    /// - Throws: Error when 'policyRequirement' attribute is missing on raw JSON response
    init(_ propertyName: String, _ json: [String: Any]) throws {
        self.params = json[JourneyConstants.params] as? [String: Any]
        if let policyRequirement = json[JourneyConstants.policyRequirement] as? String {
            self.policyRequirement = policyRequirement
        } else {
            throw NSError(domain: "FailedPolicy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse FailedPolicies from callback response: \(json)"])
        }
    }

    /// Generates, and returns human readable failed reason
    ///
    /// - Returns: String value of human readable failed policy
    public func failedDescription(for propertyName: String) -> String {

        if var failedPolicyDescription = failedPolicyMapping[policyRequirement] {

            failedPolicyDescription = failedPolicyDescription.replacingOccurrences(of: "%{propertyName}", with: propertyName)

            if let failedPolicyParams = params {
                for (key, value) in failedPolicyParams {
                    failedPolicyDescription = failedPolicyDescription.replacingOccurrences(of: "%{" + key + "}", with: String(describing: value))
                }
            }

            return failedPolicyDescription
        }

        return propertyName + ": Unknown policy requirement - " + policyRequirement
    }

    fileprivate let failedPolicyMapping: [String: String] = [
        "REQUIRED": "%{propertyName} is required",
        "UNIQUE": "%{propertyName} must be unique",
        "MATCH_REGEXP": "",
        "VALID_TYPE": "",
        "VALID_QUERY_FILTER": "",
        "VALID_ARRAY_ITEMS": "",
        "VALID_DATE": "Invalid date",
        "VALID_EMAIL_ADDRESS_FORMAT": "Invalid Email format",
        "VALID_NAME_FORMAT": "Invalid name format",
        "VALID_PHONE_FORMAT": "Invalid phone number",
        "AT_LEAST_X_CAPITAL_LETTERS": "%{propertyName} must contain at least %{numCaps} capital letter(s)",
        "AT_LEAST_X_NUMBERS": "%{propertyName} must contain at least %{numNums} numeric value(s)",
        "VALID_NUMBER": "Invalid number",
        "MINIMUM_NUMBER_VALUE": "",
        "MAXIMUM_NUMBER_VALUE": "",
        "MIN_LENGTH": "%{propertyName} must be at least %{minLength} character(s)",
        "MAX_LENGTH": "%{propertyName} must be at most %{maxLength} character(s)",
        "CANNOT_CONTAIN_OTHERS": "%{propertyName} must not contain: %{disallowedFields}",
        "CANNOT_CONTAIN_CHARACTERS": "%{propertyName} must not contain following characters: %{forbiddenChars}",
        "CANNOT_CONTAIN_DUPLICATES": "%{propertyName} must not contain duplicates: %{duplicateValue}}",
    ]
}
