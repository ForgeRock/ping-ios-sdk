// 
//  MockURLProtocol.swift
//  OrchestrateTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
import PingNetwork

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

extension MockURLProtocol {
    static func makeClient(config: HttpClientConfig = HttpClientConfig()) -> HttpClientProtocol {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return MockHttpClient(config: config, session: session, delegate: nil)
    }
}


class MockHttpClient: HttpClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let timeout: TimeInterval
    private let delegate: URLSessionTaskDelegate?
    
    var mockResponse: (Data, HTTPURLResponse)?
    var mockError: Error?
    var lastRequest: PingNetwork.HttpRequest?
    
    func request() -> any PingNetwork.HttpRequest {
        let request = URLSessionHttpRequest()
        request.url = "http://openam.example.com"
        return request
    }
    
    public init(config: HttpClientConfig, session: URLSession, delegate: URLSessionTaskDelegate? = nil) {
        self.timeout = config.timeout
        self.session = session
        self.delegate = delegate
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
        
        //fallback to normal processing
        guard let sessionRequest = request as? URLSessionHttpRequest else {
            throw NetworkError.invalidRequest("Request must be URLSessionHttpRequest")
        }
        
        guard let urlRequest = sessionRequest.buildURLRequest() else {
            throw NetworkError.invalidRequest("Failed to build URLRequest")
        }
        
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Response is not HTTPURLResponse")
        }
        
        let httpResponseObj = URLSessionHttpResponse(
            request: sessionRequest,
            body: data,
            httpURLResponse: httpResponse
        )
        
        
        return httpResponseObj
        
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
