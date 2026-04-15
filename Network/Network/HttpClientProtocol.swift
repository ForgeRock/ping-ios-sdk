//
//  HttpClientProtocol.swift
//  PingNetwork
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Protocol defining the contract for HTTP client implementations.
///
/// The `HttpClientProtocol` provides a high-level interface for making HTTP requests
/// with support for configuration, interceptors, and async/await patterns.
public protocol HttpClientProtocol: Sendable {
    /// Creates a new HTTP request instance.
    ///
    /// - Returns: A new `HttpRequest` ready for configuration.
    func request() -> HttpRequest

    /// Executes a pre-configured HTTP request.
    ///
    /// - Parameter request: The configured HTTP request to execute.
    /// - Returns: An `HttpResponse` instance
    func request(request: HttpRequest) async throws -> HttpResponse

    /// Executes an HTTP request configured via a builder closure.
    ///
    /// Example:
    /// ```swift
    /// let response = try await client.request { req in
    ///     req.url = URL(string: "https://api.example.com/users")
    ///     req.setHeader(name: "Accept", value: "application/json")
    ///     req.get()
    /// }
    /// ```
    ///
    /// - Parameter builder: A closure that configures the request.
    /// - Returns: An `HttpResponse` instance
    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async throws -> HttpResponse

    /// Closes the client and releases resources.
    ///
    /// After calling this method, the client should not be used for new requests.
    func close()
}
