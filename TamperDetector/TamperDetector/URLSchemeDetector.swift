//
//  URLSchemeDetector.swift
//  JailbreakDetector
//
//  Copyright (c) 2023 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import UIKit

/// URLSchemeDetector is a TamperDetector class, and is used as one of default TamperDetector's detectors to determine whether the device is Jailbroken or not
public class URLSchemeDetector: TamperDetectorProtocol {
    
    public init() { }

    /// Analyzes whether certain url schemes can be opened.
    ///
    /// - Returns: returns 1.0 if any of the listed url schemes can be opened; otherwise returns 0.0
    public func analyze() -> Double {
        
        // "cydia://" is not in the list as there is app in the official App Store
        // that has the cydia:// URL scheme registered, so it may cause false positive
        let urlSchemes = [
            "undecimus://",
            "sileo://",
            "zbra://",
            "filza://",
            "activator://"
        ]
        for urlScheme in urlSchemes {
            if let url = URL(string: urlScheme) {
                let canOpen = canOpenURL(url)
                if canOpen {
                    return 1.0
                }
            }
        }
        
        return 0.0
    }
    
    private func canOpenURL(_ url: URL) -> Bool {
        if Thread.isMainThread {
            return MainActor.assumeIsolated {
                UIApplication.shared.canOpenURL(url)
            }
        } else {
            return DispatchQueue.main.sync { @MainActor in
                UIApplication.shared.canOpenURL(url)
            }
        }
    }
}
