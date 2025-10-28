// 
//  ReCaptchaEnterpriseUtils.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation

// MARK: - ReCaptchaEnterpriseUtils

/// Utility functions for the ReCaptchaEnterprise module.
///
/// This struct provides helper methods for common operations needed
/// throughout the reCAPTCHA Enterprise implementation, particularly
/// for JSON serialization and data transformation.
public struct ReCaptchaEnterpriseUtils {
    
    /// Converts an object to JSON string representation.
    ///
    /// This method safely serializes any valid JSON object into its string
    /// representation, with optional pretty-printing for readability.
    ///
    /// - Parameters:
    ///   - value: The object to convert to JSON
    ///   - prettyPrinted: Whether to format JSON with indentation
    /// - Returns: JSON string, or empty string if conversion fails
    ///
    /// ## Implementation Notes
    /// - Validates JSON object before serialization
    /// - Handles serialization errors gracefully
    /// - Uses UTF-8 encoding for string conversion
    /// - Returns empty string as fallback for invalid objects
    ///
    /// ## Usage Example
    /// ```swift
    /// let data = ["action": "login", "score": 0.9]
    /// let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(value: data as AnyObject)
    /// ```
    public static func jsonStringify(
        value: AnyObject,
        prettyPrinted: Bool = false
    ) -> String {
        let options: JSONSerialization.WritingOptions = prettyPrinted ? .prettyPrinted : []
        
        guard JSONSerialization.isValidJSONObject(value) else {
            return ""
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: options)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}
