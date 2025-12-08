//
//  ErrorHandlingTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class ErrorHandlingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
        MockURLProtocol.lastRequest = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
        MockURLProtocol.lastRequest = nil
        super.tearDown()
    }

    func testInvalidURLStringFails() async {
        let client = makeClient()
        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "ht tp://bad"
            mutable.get()
        }

        switch result {
        case .success:
            XCTFail("Expected failure for invalid URL")
        case .failure(let error):
            guard case NetworkError.invalidRequest = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testJsonSerializationErrorReturnsInvalidRequest() async {
        let client = makeClient()
        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com"
            mutable.post(json: ["date": Date()]) // Date is not JSON-serializable
        }

        switch result {
        case .success:
            XCTFail("Expected serialization error")
        case .failure(let error):
            guard case NetworkError.invalidRequest = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testNonHTTPResponseMapsToInvalidResponse() async {
        let config = HttpClientConfig()
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [NonHTTPURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        let client = URLSessionHttpClient(config: config, session: session, delegate: nil)

        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com"
            mutable.get()
        }

        switch result {
        case .success:
            XCTFail("Expected invalidResponse error")
        case .failure(let error):
            guard case NetworkError.invalidResponse = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testTimeoutAndNetworkUnavailableMappings() async {
        let client = makeClient()

        func assertMapping(code: URLError.Code, expected: NetworkError) async {
            MockURLProtocol.requestHandler = { _ in throw URLError(code) }
            let result = await client.request { req in
                guard let mutable = req as? URLSessionHttpRequest else { return }
                mutable.url = "https://example.com"
                mutable.get()
            }
            switch result {
            case .success:
                XCTFail("Expected failure for \(code)")
            case .failure(let error):
                guard let networkError = error as? NetworkError else {
                    XCTFail("Unexpected error \(error)")
                    return
                }
                switch (networkError, expected) {
                case (.timeout, .timeout),
                     (.networkUnavailable, .networkUnavailable),
                     (.cancelled, .cancelled):
                    break
                default:
                    XCTFail("Unexpected error \(networkError)")
                }
            }
        }

        await assertMapping(code: .timedOut, expected: .timeout)
        await assertMapping(code: .notConnectedToInternet, expected: .networkUnavailable)
        await assertMapping(code: .cancelled, expected: .cancelled)
    }

    private func makeClient(config: HttpClientConfig = HttpClientConfig()) -> URLSessionHttpClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return URLSessionHttpClient(config: config, session: session, delegate: nil)
    }
}

private final class NonHTTPURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
