//
//  HttpClient.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Factory helper for creating HTTP client instances.
///
/// This enum provides a convenient factory method for creating HTTP clients
/// without needing to reference the concrete implementation type directly.
///
/// Example:
/// ```swift
/// let client = HttpClient.createClient { config in
///     config.timeout = 30.0
///     config.onRequest { req in
///         req.setHeader(name: "User-Agent", value: "MyApp/1.0")
///     }
/// }
/// ```
public enum HttpClient {
    /// Creates a new HTTP client instance with optional configuration.
    ///
    /// This factory method creates a URLSession-based HTTP client with sensible defaults.
    /// You can customize the client behavior using the configuration closure.
    ///
    /// - Parameter configure: A closure that configures the HTTP client.
    /// - Returns: A configured HTTP client instance conforming to `HttpClientProtocol`.
    public static func createClient(
        _ configure: (HttpClientConfig) -> Void = { _ in }
    ) -> any HttpClientProtocol {
        URLSessionHttpClient.createClient(configure)
    }
}
