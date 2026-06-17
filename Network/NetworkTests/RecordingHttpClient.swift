//
//  RecordingHttpClient.swift
//  NetworkTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
@testable import PingNetwork

/// One captured outgoing HTTP request. Populated by `RecordingHttpClient` from the
/// built `URLRequest` just before it is dispatched to the real network.
struct RecordedRequest: Sendable {
    let url: URL?
    let method: String?
    let headers: [String: String]
    let body: Data?

    var path: String { url?.path ?? "" }

    /// Returns the URL query items, e.g. for asserting the authorize URL shape.
    func queryItems() -> [URLQueryItem] {
        guard let url, let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return []
        }
        return comps.queryItems ?? []
    }

    /// Parses a `application/x-www-form-urlencoded` body into a key→value dictionary.
    /// Returns an empty dictionary for any other content type.
    func formFields() -> [String: String] {
        guard let body, let str = String(data: body, encoding: .utf8) else { return [:] }
        var out: [String: String] = [:]
        for pair in str.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard kv.count == 2 else { continue }
            let k = String(kv[0]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[0])
            let v = String(kv[1]).replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? String(kv[1])
            out[k] = v
        }
        return out
    }
}

/// Thread-safe list of captured requests. Tests call `history`, `first(matchingPathSuffix:)`,
/// or `all(matchingPathSuffix:)` after the flow completes.
final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [RecordedRequest] = []

    func append(_ r: RecordedRequest) {
        lock.lock(); defer { lock.unlock() }
        items.append(r)
    }

    var history: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return items
    }

    func first(matchingPathSuffix suffix: String) -> RecordedRequest? {
        history.first { $0.url?.path.hasSuffix(suffix) ?? false }
    }

    func all(matchingPathSuffix suffix: String) -> [RecordedRequest] {
        history.filter { $0.url?.path.hasSuffix(suffix) ?? false }
    }
}

/// Test-only `HttpClientProtocol` wrapper that records every outgoing request into
/// `recorder` before forwarding to a real URLSession-backed client.
///
/// The network call is **real** — there is no mocking. Use this in integration tests
/// to assert the exact wire shape (PAR push body, /authorize query string, etc.)
/// the SDK produces against a live server.
///
/// Each test target (JourneyTests, DavinciTests, OidcTests) references this single
/// file from `Network/NetworkTests/` via a relative cross-project path in its pbxproj.
final class RecordingHttpClient: HttpClientProtocol, @unchecked Sendable {
    let recorder: RequestRecorder
    private let inner: any HttpClientProtocol

    init(recorder: RequestRecorder = RequestRecorder(), timeout: TimeInterval = 30) {
        self.recorder = recorder
        self.inner = HttpClient.createClient { config in
            config.timeout = timeout
        }
    }

    func request() -> HttpRequest {
        inner.request()
    }

    func request(request: HttpRequest) async throws -> HttpResponse {
        // Snapshot is pre-interceptor: any headers/mutations added by requestInterceptors
        // inside URLSessionHttpClient will not appear in the recorded request.
        record(request)
        return try await inner.request(request: request)
    }

    func request(builder: @escaping @Sendable (HttpRequest) -> Void) async throws -> HttpResponse {
        let req = inner.request()
        builder(req)
        record(req)
        return try await inner.request(request: req)
    }

    func close() {
        inner.close()
    }

    private func record(_ request: HttpRequest) {
        guard let urlRequest = (request as? URLSessionHttpRequest)?.buildURLRequest() else {
            assertionFailure("RecordingHttpClient: expected URLSessionHttpRequest, got \(type(of: request)) — recording skipped")
            return
        }
        recorder.append(
            RecordedRequest(
                url: urlRequest.url,
                method: urlRequest.httpMethod,
                headers: urlRequest.allHTTPHeaderFields ?? [:],
                body: urlRequest.httpBody
            )
        )
    }
}
