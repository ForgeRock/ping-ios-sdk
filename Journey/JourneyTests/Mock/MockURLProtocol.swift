//
//  MockURLProtocol.swift
//  JourneyTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingOrchestrate
@testable import PingNetwork

class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) public static var requestHistory: [URLRequest] = [URLRequest]()
    
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    static func startInterceptingRequests() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }
    
    static func stopInterceptingRequests() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        requestHistory.removeAll()
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        MockURLProtocol.requestHistory.append(request)
        
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received unexpected request with no handler set")
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {
        
    }
}

// MARK: - Mock Classes
class MockSession: Session, @unchecked Sendable {
    let sessionValue: String
    
    init(value: String = "test-session") {
        self.sessionValue = value
    }
    
    var value: String {
        return sessionValue
    }
}

class MockHttpClient: HttpClientProtocol, @unchecked Sendable {
    var mockResponse: (Data, HTTPURLResponse)?
    var mockError: Error?
    var lastRequest: PingNetwork.HttpRequest?
    
    func request() -> any PingNetwork.HttpRequest {
        URLSessionHttpRequest()
    }
    
    func request(request: any PingNetwork.HttpRequest) async throws -> any PingNetwork.HttpResponse {
        lastRequest = request
        if let error = mockError {
            throw error
        }
        
        if let response = mockResponse {
            let httprResponse = MockHttpResponseImpl(
                request: request,
                statusCode: response.1.statusCode,
                body: response.0, allHeaderFields: response.1.allHeaderFields
            )
            return httprResponse
        }
        
        throw NSError(domain: "Test", code: 0, userInfo: nil)
    }
    
    func request(builder: @escaping @Sendable (any PingNetwork.HttpRequest) -> Void) async throws -> any PingNetwork.HttpResponse {
        let request = self.request()
        builder(request)
        return try await self.request(request: request)
    }
    
    func close() {
        
    }
}


/// Mock HTTP response implementation
final class MockHttpResponseImpl: PingNetwork.HttpResponse {
    func bodyAsString() -> String {
        return ""
    }
    
    let request: HttpRequest
    let status: Int
    let body: Data?
    let headers: [String: [String]]
    
    init(request: HttpRequest, statusCode: Int, body: Data?, allHeaderFields: [AnyHashable : Any]) {
        self.request = request
        self.status = statusCode
        self.body = body
        let headerMap = allHeaderFields.reduce(into: [String: [String]]()) { result, pair in
            if let key = pair.key as? String {
                let normalizedKey = key.lowercased()
                var values = result[normalizedKey] ?? []
                values.append("\(pair.value)")
                result[normalizedKey] = values
            }
        }
        self.headers = headerMap
    }
    
    func getHeader(name: String) -> String? {
        return headers[name]?.first
    }
    
    func getHeaders(name: String) -> [String]? {
        return headers[name]
    }
    
    func getCookies() -> [HTTPCookie] {
        return []
    }
    
    func getCookieStrings() -> [String] {
        return []
    }
}


extension MockURLProtocol {
    static func makeClient(config: HttpClientConfig = HttpClientConfig()) -> URLSessionHttpClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return URLSessionHttpClient(config: config, session: session, delegate: nil)
    }
}
