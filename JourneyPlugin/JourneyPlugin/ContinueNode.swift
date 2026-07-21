//
//  ContinueNode.swift
//  PingJourneyPlugin
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOrchestrate
import Foundation

extension ContinueNode {
    /// A human-readable description for this node, derived from the Journey Page Node field
    public var pageDescription: String {
        if let value = input[JourneyConstants.description] as? String {
            return value
        }
        return ""
    }
    
    /// The submit button text for this node. Can be derived from:
    /// 1. A localized value in the `stage` field's JSON (e.g., {"submitButtonText":{"en-gb":"Submit"}})
    /// 2. The form description field (legacy support)
    public var submitButtonText: String {
        // First, try to get localized value from stage JSON
        if let localizedValue = getLocalizedValueFromStage(key: JourneyConstants.submitButtonText) {
            return localizedValue
        }
        
        return ""
    }
    
    /// The header text for this node, if provided in the Journey Page Node field
    public var pageHeader: String {
        if let value = input[JourneyConstants.header] as? String {
            return value
        }
        return ""
    }
    
    /// The footer text for this node. Can be derived from:
    /// 1. A localized value in the `stage` field's JSON (e.g., {"pageFooter":{"en-gb":"Footer"}})
    /// 2. The form footer field (legacy support)
    public var pageFooter: String {
        // First, try to get localized value from stage JSON
        if let localizedValue = getLocalizedValueFromStage(key: JourneyConstants.pageFooter) {
            return localizedValue
        }
        return ""
    }
    
    /// The stage identifier for this node, if provided in the Journey Page Node field.
    /// Note: This may contain a simple string or a JSON string with localized values.
    public var stage: String {
        if let value = input[JourneyConstants.stage] as? String {
            return value
        }
        return ""
    }
    
    /// Returns the list of callbacks from this node's actions.
    public var callbacks: [any Callback] {
        return actions.compactMap { $0 as? (any Callback) }
    }
    
    // MARK: - Private Helper Methods
    
    /// Attempts to extract a localized value from the `stage` field's JSON structure.
    ///
    /// The stage field may contain a JSON string like:
    /// ```
    /// {"submitButtonText":{"en-gb":"Submit"},"pageFooter":{"en-gb":"Footer"}}
    /// ```
    ///
    /// This method parses the JSON and returns the best matching localized value based on
    /// the user's preferred locales. It tries to find an exact match first, then falls back
    /// to language-only matches (e.g., "en" for "en-gb").
    ///
    /// - Parameter key: The key to look up in the JSON (e.g., "submitButtonText" or "pageFooter")
    /// - Returns: The localized string value, or `nil` if not found
    private func getLocalizedValueFromStage(key: String) -> String? {
        guard let stageValue = input[JourneyConstants.stage] as? String,
              !stageValue.isEmpty,
              let jsonData = stageValue.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let localizedDict = jsonObject[key] as? [String: String] else {
            return nil
        }
        
        // If there's only one value, return it
        if localizedDict.count == 1, let value = localizedDict.values.first {
            return value
        }
        
        // Try to find the best match based on user's preferred locales
        let preferredLocales: [Locale]
        if #available(iOS 26, macOS 26, *) {
            preferredLocales = Locale.preferredLocales
        } else {
            // Fallback for iOS 16+ / macOS 13+
            preferredLocales = Locale.preferredLanguages.map { Locale(identifier: $0) }
        }
        
        for locale in preferredLocales {
            let identifier = locale.identifier.lowercased()
            
            // Try exact match first (e.g., "en-gb")
            if let value = localizedDict[identifier] {
                return value
            }
            
            // Try with underscore instead of hyphen (e.g., "en_GB")
            let underscoreIdentifier = identifier.replacingOccurrences(of: "-", with: "_")
            if let value = localizedDict[underscoreIdentifier] {
                return value
            }
            
            // Try language code only (e.g., "en" from "en-GB")
            if #available(iOS 16, macOS 13, watchOS 9, tvOS 16, visionOS 1, *) {
                if let languageCode = locale.language.languageCode?.identifier.lowercased() {
                    if let value = localizedDict[languageCode] {
                        return value
                    }
                }
            } else {
                // Fallback for older OS versions
                if let languageCode = locale.languageCode?.lowercased() {
                    if let value = localizedDict[languageCode] {
                        return value
                    }
                }
            }
        }
        
        // If no match found, return the first available value
        return localizedDict.values.first
    }
}
