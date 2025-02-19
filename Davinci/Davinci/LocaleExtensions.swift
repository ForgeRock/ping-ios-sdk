// 
//  LocaleExtensions.swift
//  Davinci
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

extension Locale {
    public static var preferredLocales: [Locale] {
        Locale.preferredLanguages.map {Locale(identifier: $0)}
    }
}

extension Array where Element == Locale {
    public func toAcceptLanguage() -> String {
        if isEmpty { return "" }
        
        var languageTags: [String] = []
        var currentQValue = 0.9
        
        for (index, locale) in enumerated() {
            // Add language tag version first
            if index == 0 {
                languageTags.append(locale.identifier)
                currentQValue = 0.9
            } else {
                languageTags.append("\(locale.identifier);q=\(String(format: "%.1f", currentQValue))")
                currentQValue = Swift.max(0.1, currentQValue - 0.1)
            }
            
            // Add language version with next q-value
            let languageCode = locale.languageCode ?? ""
            if locale.identifier != languageCode && !languageCode.isEmpty {
                languageTags.append("\(languageCode);q=\(String(format: "%.1f", currentQValue))")
                currentQValue = Swift.max(0.1, currentQValue - 0.1)
            }
        }
        
        return languageTags.joined(separator: ", ")
    }
}


func getAcceptLanguageHeader() -> String {
    // Get preferred languages from system settings
    let preferredLanguages = Locale.preferredLanguages
    
    // Create language tags with quality values
    let languageTags = preferredLanguages.enumerated().map { index, language -> String in
        let quality = 1.0 - (Double(index) * 0.1)
        let q = max(0.1, quality)
        return "\(language);q=\(String(format: "%.1f", q))"
    }
    
    return languageTags.joined(separator: ", ")
}
