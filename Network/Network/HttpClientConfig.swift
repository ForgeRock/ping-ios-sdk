//
//  HttpClientConfig.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// Configuration class for HTTP client instances.
///
/// `HttpClientConfig` provides a DSL-style interface for configuring
/// HTTP client behavior including timeouts, logging, and interceptors.
/// Configure this once up front; it is not intended for concurrent mutation after use.
///
/// Example:
/// ```swift
/// let config = HttpClientConfig()
/// config.timeout = 30.0
/// config.logger = LogManager.standard
/// config.onRequest { request in
///     request.setHeader(name: "Authorization", value: "Bearer \(token)")
/// }
/// config.onResponse { response in
///     config.logger.d("Status \(response.status)")
/// }
/// ```
public final class HttpClientConfig {
    /// Request timeout in seconds. Defaults to 15 seconds to match Android implementation.
    public var timeout: TimeInterval = 15.0

    /// Logger instance for network operations. Defaults to warning level.
    public var logger: Logger = LogManager.warning

    /// Internal storage for request interceptors.
    internal private(set) var requestInterceptors: [HttpRequestInterceptor] = []

    /// Internal storage for response interceptors.
    internal private(set) var responseInterceptors: [HttpResponseInterceptor] = []

    /// Registers a request interceptor. Executed in registration order.
    /// - Parameter interceptor: The interceptor closure.
    public func onRequest(_ interceptor: @escaping HttpRequestInterceptor) {
        requestInterceptors.append(interceptor)
    }

    /// Registers a response interceptor. Executed in registration order.
    /// - Parameter interceptor: The interceptor closure.
    public func onResponse(_ interceptor: @escaping HttpResponseInterceptor) {
        responseInterceptors.append(interceptor)
    }

    /// Creates a default configuration.
    public init() {}
}

public extension HttpClientConfig {
    /// Default HTTP client configuration.
    static var `default`: HttpClientConfig { HttpClientConfig() }
}
