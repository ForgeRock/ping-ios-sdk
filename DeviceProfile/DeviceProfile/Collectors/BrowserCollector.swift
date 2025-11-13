//
//  BrowserCollector.swift
//  DeviceProfile
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import WebKit

// MARK: - BrowserCollector

/// Collector for browser user agent information.
///
/// This collector retrieves the user agent string from the device's WebKit engine,
/// which provides information about the browser, device, and system version
/// that web applications would see when making requests.
public class BrowserCollector: DeviceCollector, @unchecked Sendable {
    public typealias DataType = BrowserInfo

    /// Unique identifier for browser information data
    public let key = "browser"

    /// Collects browser user agent information
    /// - Returns: BrowserInfo containing the user agent string
    public func collect() async -> BrowserInfo? {
        return await BrowserInfo.create()
    }
    
    /// Initializes a new instance
    public init() {}
}

// MARK: - BrowserInfo

/// Information about the device's browser user agent.
///
/// This structure contains the user agent string that identifies the browser,
/// device type, operating system, and other capabilities to web servers.
public struct BrowserInfo: Codable, Sendable {
    /// The browser user agent string
    /// - Note: This is the same user agent that would be sent in HTTP requests
    let userAgent: String

    /// Initializes browser info with the provided user agent
    /// - Parameter userAgent: The browser user agent string
    init(userAgent: String) {
        self.userAgent = userAgent
    }

    /// Creates BrowserInfo by fetching the actual browser user agent from WKWebView.
    ///
    /// This method creates a temporary WKWebView instance and evaluates JavaScript
    /// to retrieve the navigator.userAgent property, which provides the most
    /// accurate user agent string available on the device.
    ///
    /// - Returns: BrowserInfo with real browser user agent, or nil if unable to fetch
    ///
    /// ## Implementation Notes
    /// - Must be called on the main thread due to WKWebView requirements
    /// - Falls back to WKWebView's internal user agent if JavaScript fails
    /// - Returns "Unknown" as last resort if all methods fail
    ///
    /// ## Example User Agent
    /// ```
    /// Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)
    /// AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1
    /// ```
    static func create() async -> BrowserInfo? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let webView = WKWebView()
                
                // Attempt to get user agent via JavaScript evaluation
                webView.evaluateJavaScript(DeviceProfileConstants.navigator_userAgent) { result, error in
                    if let userAgent = result as? String {
                        continuation.resume(returning: BrowserInfo(userAgent: userAgent))
                    } else {
                        // Fallback to WebView's internal user agent property
                        let fallbackUserAgent = webView.value(forKey: DeviceProfileConstants.userAgent) as? String ?? DeviceProfileConstants.unknown
                        continuation.resume(returning: BrowserInfo(userAgent: fallbackUserAgent))
                    }
                }
            }
        }
    }
}
