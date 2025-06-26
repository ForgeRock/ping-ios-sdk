//
//  MockURLProtocol.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingOrchestrate

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

class MockHttpClient: HttpClient, @unchecked Sendable {
    var mockResponse: (Data, URLResponse)?
    var mockError: Error?
    var lastRequest: Request?
    
    override func sendRequest(request: Request) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = mockError {
            throw error
        }
        if let response = mockResponse {
            return response
        }
        throw OidcError.networkError(message: "No mock response set")
    }
}
