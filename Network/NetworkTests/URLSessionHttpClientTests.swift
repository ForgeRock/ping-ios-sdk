//
//  URLSessionHttpClientTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class URLSessionHttpClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
        MockURLProtocol.lastRequest = nil
        RedirectURLProtocol.requestCount = 0
    }

    override func tearDown() {
        super.tearDown()
        MockURLProtocol.requestHandler = nil
        MockURLProtocol.requestCount = 0
        MockURLProtocol.lastRequest = nil
        RedirectURLProtocol.requestCount = 0
    }

    func testDefaultConfigExecutesGetRequest() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.lastRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!
            return (response, Data("ok".utf8))
        }

        let client = makeClient()
        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com/path"
            mutable.get()
        }

        switch result {
        case .success(let response):
            XCTAssertEqual(response.status, 200)
            XCTAssertEqual(response.bodyAsString(), "ok")
            XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "GET")
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }
    }

    func testCustomConfigSupportsHttpMethods() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.requestCount += 1
            MockURLProtocol.lastRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let config = HttpClientConfig()
        config.timeout = 5

        let client = makeClient(config: config)

        let url = "https://example.com/resource"

        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.post(json: ["a": 1])
        }
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.put(json: ["b": 2])
        }
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "PUT")

        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.delete(json: ["c": "del"])
        }
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "DELETE")

        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.form(parameters: ["a": "1", "b": "2"])
        }
        XCTAssertEqual(MockURLProtocol.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(MockURLProtocol.requestCount, 4)
    }

    func testInterceptorsExecuteInOrder() async {
        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.lastRequest = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["X-Resp": "done"])!
            return (response, Data())
        }

        let requestOrder = OrderRecorder()
        let responseOrder = OrderRecorder()

        let config = HttpClientConfig()
        config.onRequest { request in
            requestOrder.append("first")
            guard let mutable = request as? URLSessionHttpRequest else { return }
            mutable.setHeader(name: "X-Chain", value: "1")
        }
        config.onRequest { request in
            requestOrder.append("second")
            guard let mutable = request as? URLSessionHttpRequest else { return }
            let current = mutable.getHeader(name: "X-Chain") ?? ""
            mutable.setHeader(name: "X-Chain", value: "\(current),2")
        }

        config.onResponse { _ in responseOrder.append("first") }
        config.onResponse { _ in responseOrder.append("second") }

        let client = makeClient(config: config)

        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com"
            mutable.get()
        }

        switch result {
        case .success:
            XCTAssertEqual(requestOrder.snapshot(), ["first", "second"])
            XCTAssertEqual(responseOrder.snapshot(), ["first", "second"])
            XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Chain"), "1,2")
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }
    }

    func testStandardHeadersAndInterceptor() async {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: NetworkConstants.headerRequestedWith), NetworkConstants.requestedWithValue)
            XCTAssertEqual(request.value(forHTTPHeaderField: NetworkConstants.headerRequestedPlatform), NetworkConstants.requestedPlatformValue)
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Custom"), "yes")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["X-Resp": "1"])!
            return (response, Data())
        }

        let config = HttpClientConfig()
        config.onRequest { request in
            guard let mutable = request as? URLSessionHttpRequest else { return }
            mutable.setHeader(name: "X-Custom", value: "yes")
        }

        let client = makeClient(config: config)
        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com"
            mutable.get()
        }

        switch result {
        case .success(let response):
            XCTAssertEqual(response.status, 200)
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }
    }

    func testErrorMappings() async {
        let client = makeClient()
        let url = "https://example.com"

        func assertError(code: URLError.Code, expected: NetworkError, file: StaticString = #filePath, line: UInt = #line) async {
            MockURLProtocol.requestHandler = { _ in throw URLError(code) }
            let result = await client.request { req in
                guard let mutable = req as? URLSessionHttpRequest else { return }
                mutable.url = url
                mutable.get()
            }

            switch result {
            case .success:
                XCTFail("Expected error for \(code)", file: file, line: line)
            case .failure(let error):
                switch (error, expected) {
                case (NetworkError.timeout, NetworkError.timeout),
                     (NetworkError.networkUnavailable, NetworkError.networkUnavailable),
                     (NetworkError.cancelled, NetworkError.cancelled):
                    break
                default:
                    XCTFail("Unexpected error \(error)", file: file, line: line)
                }
            }
        }

        await assertError(code: .timedOut, expected: .timeout)
        await assertError(code: .notConnectedToInternet, expected: .networkUnavailable)
        await assertError(code: .cancelled, expected: .cancelled)
    }

    func testHandlesErrorStatusResponses() async {
        var statuses = [404, 500]
        MockURLProtocol.requestHandler = { request in
            let status = statuses.removeFirst()
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let client = makeClient()
        let url = "https://example.com"

        let first = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.get()
        }

        let second = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = url
            mutable.get()
        }

        switch first {
        case .success(let response):
            XCTAssertEqual(response.status, 404)
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }

        switch second {
        case .success(let response):
            XCTAssertEqual(response.status, 500)
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }
    }

    func testInvalidURLFails() async {
        let client = makeClient()
        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.get()
        }

        switch result {
        case .success:
            XCTFail("Expected failure for missing URL")
        case .failure(let error):
            guard case NetworkError.invalidRequest = error else {
                XCTFail("Unexpected error \(error)")
                return
            }
        }
    }

    func testRedirectIsNotFollowed() async {
        RedirectURLProtocol.requestCount = 0

        let config = HttpClientConfig()
        let delegate = RedirectPreventerDelegate()

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [RedirectURLProtocol.self]

        let session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)
        let client = URLSessionHttpClient(config: config, session: session, delegate: delegate)

        let result = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com/redirect"
            mutable.get()
        }

        switch result {
        case .success(let response):
            XCTAssertEqual(response.status, 302)
            XCTAssertEqual(RedirectURLProtocol.requestCount, 1)
        case .failure(let error):
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeClient(config: HttpClientConfig = HttpClientConfig()) -> URLSessionHttpClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return URLSessionHttpClient(config: config, session: session, delegate: nil)
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount: Int = 0
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            XCTFail("Handler not set")
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

    override func stopLoading() {}
}

final class RedirectURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestCount: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        guard let url = request.url else { return }
        let redirectURL = url.appendingPathComponent("next")
        let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": redirectURL.absoluteString])!

        client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: redirectURL), redirectResponse: response)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OrderRecorder: @unchecked Sendable {
    private var values: [String] = []
    private let lock = NSLock()

    func append(_ value: String) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let copy = values
        lock.unlock()
        return copy
    }
}
