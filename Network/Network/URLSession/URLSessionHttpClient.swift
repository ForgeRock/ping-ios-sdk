//
//  URLSessionHttpClient.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingLogger

/// URLSession-based implementation of `HttpClientProtocol`.
///
/// Applies request/response interceptors, injects standard headers, and
/// prevents automatic redirects.
///
/// This class is **thread-safe** and can be safely shared across multiple threads
/// and async contexts. All mutable state is confined to the URLSession instance,
/// which is itself thread-safe.
///
/// Multiple concurrent requests can safely use the same client instance.
public final class URLSessionHttpClient: HttpClientProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    private let session: URLSession
    private let timeout: TimeInterval
    private let logger: Logger
    private let delegate: URLSessionTaskDelegate?
    
    /// Immutable copy of request interceptors, frozen at initialization for thread-safe access.
    private let requestInterceptors: [HttpRequestInterceptor]
    
    /// Immutable copy of response interceptors, frozen at initialization for thread-safe access.
    private let responseInterceptors: [HttpResponseInterceptor]

    internal convenience init(config: HttpClientConfig) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.httpShouldSetCookies = true
        sessionConfig.httpCookieAcceptPolicy = .always

        let delegate = RedirectPreventerDelegate()
        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        self.init(config: config, session: session, delegate: delegate)
    }

    // MARK: - Factory Method
    
    /// Creates a new URLSession-based HTTP client instance with optional configuration.
    ///
    /// - Parameter configure: A closure that configures the HTTP client.
    /// - Returns: A configured `URLSessionHttpClient` instance.
    public static func createClient(
        _ configure: (HttpClientConfig) -> Void = { _ in }
    ) -> URLSessionHttpClient {
        let config = HttpClientConfig()
        configure(config)
        return URLSessionHttpClient(config: config)
    }
    
    /// Creates a new HTTP client with custom URLSession configuration.
    ///
    /// This initializer allows injecting a custom URLSession for testing or advanced configuration.
    /// Interceptor arrays are copied from the config at initialization to ensure thread-safe immutability.
    ///
    /// - Parameters:
    ///   - config: The HTTP client configuration.
    ///   - session: The URLSession to use for requests.
    ///   - delegate: Optional URLSessionTaskDelegate for handling redirects and authentication.
    public init(config: HttpClientConfig, session: URLSession, delegate: URLSessionTaskDelegate? = nil) {
        self.timeout = config.timeout
        self.session = session
        self.logger = config.logger
        self.delegate = delegate
        // Copy interceptor arrays to make them immutable and thread-safe
        self.requestInterceptors = config.requestInterceptors
        self.responseInterceptors = config.responseInterceptors
    }

    /// Creates a new HTTP request instance ready for configuration.
    ///
    /// - Returns: A new `URLSessionHttpRequest` with standard headers pre-configured.
    public func request() -> HttpRequest {
        URLSessionHttpRequest()
    }

    /// Executes a pre-configured HTTP request asynchronously.
    ///
    /// This method applies all registered request interceptors, performs the HTTP call,
    /// and applies response interceptors before returning the result.
    ///
    /// - Parameter request: The configured HTTP request to execute.
    /// - Returns: A `Result` containing the HTTP response or an error.
    public func request(request: HttpRequest) async -> Result<HttpResponse, Error> {
        guard let sessionRequest = request as? URLSessionHttpRequest else {
            return .failure(NetworkError.invalidRequest("Request must be URLSessionHttpRequest"))
        }

        requestInterceptors.forEach { $0(sessionRequest) }

        guard let urlRequest = sessionRequest.buildURLRequest() else {
            return .failure(NetworkError.invalidRequest("Failed to build URLRequest"))
        }

        logger.d("HTTP Request: \(urlRequest.httpMethod ?? "") \(urlRequest.url?.absoluteString ?? "")")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(NetworkError.invalidResponse("Response is not HTTPURLResponse"))
            }

            let immutableRequest = ImmutableHttpRequest(original: sessionRequest)
            let headerMap = httpResponse.allHeaderFields.reduce(into: [String: [String]]()) { result, pair in
                if let key = pair.key as? String {
                    let normalizedKey = key.lowercased()
                    var values = result[normalizedKey] ?? []
                    values.append("\(pair.value)")
                    result[normalizedKey] = values
                }
            }

            let httpResponseObj = URLSessionHttpResponse(
                request: immutableRequest,
                status: httpResponse.statusCode,
                headers: headerMap,
                body: data,
                httpURLResponse: httpResponse
            )

            responseInterceptors.forEach { $0(httpResponseObj) }

            logger.d("HTTP Response: \(httpResponseObj.status) (\(data.count) bytes)")
            return .success(httpResponseObj)
        } catch {
            return .failure(mapError(error))
        }
    }

    /// Executes an HTTP request configured via a builder closure.
    ///
    /// This convenience method creates a new request, configures it using the provided closure,
    /// and executes it in one call.
    ///
    /// Example:
    /// ```swift
    /// let result = await client.request { req in
    ///     req.url = "https://api.example.com/users"
    ///     req.setHeader(name: "Accept", value: "application/json")
    ///     req.get()
    /// }
    /// ```
    ///
    /// - Parameter builder: A closure that configures the HTTP request.
    /// - Returns: A `Result` containing the HTTP response or an error.
    public func request(builder: @escaping @Sendable (HttpRequest) -> Void) async -> Result<HttpResponse, Error> {
        let request = self.request()
        builder(request)
        return await self.request(request: request)
    }

    /// Invalidates the URLSession and cancels all pending tasks.
    ///
    /// After calling this method, the client cannot be used for new requests.
    /// All outstanding tasks will be cancelled.
    public func close() {
        session.invalidateAndCancel()
    }

    private func mapError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else {
            logger.e("HTTP Error: \(error.localizedDescription)", error: error)
            return error
        }

        let mapped: NetworkError
        switch urlError.code {
        case .timedOut:
            mapped = .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            mapped = .networkUnavailable
        case .cancelled:
            mapped = .cancelled
        default:
            logger.e("HTTP Error: \(urlError.localizedDescription)", error: urlError)
            return urlError
        }
        logger.e("HTTP Error: \(mapped.localizedDescription)", error: mapped)
        return mapped
    }
}

/// URLSessionDelegate that prevents HTTP redirects.
final class RedirectPreventerDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}


