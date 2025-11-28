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

/// URLSession-based implementation of `HttpClient`.
///
/// Applies request/response interceptors, injects standard headers, and
/// prevents automatic redirects to mirror Android parity.
public final class URLSessionHttpClient: HttpClient, @unchecked Sendable {
    private let session: URLSession
    private let config: HttpClientConfig
    private let logger: Logger
    private let delegate: URLSessionTaskDelegate?

    internal convenience init(config: HttpClientConfig) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.httpShouldSetCookies = true
        sessionConfig.httpCookieAcceptPolicy = .always

        let delegate = RedirectPreventerDelegate()
        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        self.init(config: config, session: session, delegate: delegate)
    }

    public init(config: HttpClientConfig, session: URLSession, delegate: URLSessionTaskDelegate? = nil) {
        self.config = config
        self.session = session
        self.logger = config.logger
        self.delegate = delegate
    }

    public func request() -> HttpRequest {
        URLSessionHttpRequest()
    }

    public func request(request: HttpRequest) async -> Result<HttpResponse, Error> {
        guard let sessionRequest = request as? URLSessionHttpRequest else {
            return .failure(NetworkError.invalidRequest("Request must be URLSessionHttpRequest"))
        }

        config.requestInterceptors.forEach { $0(sessionRequest) }

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

            config.responseInterceptors.forEach { $0(httpResponseObj) }

            logger.d("HTTP Response: \(httpResponseObj.status) (\(data.count) bytes)")
            return .success(httpResponseObj)
        } catch {
            return .failure(mapError(error))
        }
    }

    public func request(builder: @escaping @Sendable (HttpRequest) -> Void) async -> Result<HttpResponse, Error> {
        let request = self.request()
        builder(request)
        return await self.request(request: request)
    }

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

/// Public factory function to create HTTP client instances.
///
/// Example:
/// ```swift
/// let client = createHttpClient { config in
///     config.timeout = 30.0
///     config.onRequest { req in
///         req.setHeader(name: "User-Agent", value: "MyApp/1.0")
///     }
/// }
/// ```
public func createHttpClient(configBuilder: (HttpClientConfig) -> Void = { _ in }) -> HttpClient {
    let config = HttpClientConfig()
    configBuilder(config)
    return URLSessionHttpClient(config: config)
}
