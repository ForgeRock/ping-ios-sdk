//
//  ImmutableHttpRequest.swift
//  PingNetwork
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation

/// Read-only wrapper around `URLSessionHttpRequest` for response consumption.
///
/// It provides immutable access to request data when attached to HTTP responses.
/// All mutation methods are implemented as no-ops to preserve immutability.
///
/// This class is **thread-safe** for read operations. It wraps an original request instance
/// but all mutation operations are no-ops, making it safe to share across threads.
final class ImmutableHttpRequest: HttpRequest, @unchecked Sendable {
    private let original: URLSessionHttpRequest

    init(original: URLSessionHttpRequest) {
        self.original = original
    }

    var url: String? {
        get { original.url }
        set { /* no-op to preserve immutability */ }
    }

    func setParameter(name: String, value: String) {}

    func setHeader(name: String, value: String) {}

    func setCookie(cookie: String) {}

    func setCookies(cookies: [String]) {}

    func get() {}

    func post(json: [String : Any]) {}

    func put(json: [String : Any]) {}

    func delete(json: [String : Any]) {}

    func post(contentType: String, body: String) {}

    func put(contentType: String, body: String) {}

    func delete(contentType: String, body: String) {}

    func form(parameters: [String: String]) {}

    func setMethod(_ method: HttpMethod) {}

    func setBody(_ body: Data?) {}

    func getMethod() -> HttpMethod {
        original.getMethod()
    }

    func getHeader(name: String) -> String? {
        original.getHeader(name: name)
    }

    func getHeaders() -> [String: String] {
        original.getHeaders()
    }
}
