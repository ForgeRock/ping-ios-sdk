//
//  InterceptorTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class InterceptorTests: XCTestCase {
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

    func testRequestInterceptorsModifyURLAndHeaders() async {
        let expectation = XCTestExpectation(description: "request handled")

        MockURLProtocol.requestHandler = { request in
            MockURLProtocol.lastRequest = request
            expectation.fulfill()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let executed = OrderRecorder()
        let config = HttpClientConfig()
        config.onRequest { request in
            executed.append("first")
            guard let mutable = request as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com/modified"
            mutable.setHeader(name: "X-From-Interceptor", value: "1")
        }
        config.onRequest { request in
            executed.append("second")
            guard let mutable = request as? URLSessionHttpRequest else { return }
            mutable.setParameter(name: "q", value: "test")
        }

        let client = makeClient(config: config)
        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com/original"
            mutable.get()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(executed.snapshot(), ["first", "second"])
        XCTAssertEqual(MockURLProtocol.lastRequest?.url?.absoluteString, "https://example.com/modified?q=test")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-From-Interceptor"), "1")
    }

    func testResponseInterceptorReceivesImmutableRequestAndStandardHeaders() async {
        let expectation = XCTestExpectation(description: "response handled")
        let seenType = ValueRecorder<String>()
        let seenHeader = ValueRecorder<String>()
        let responseOrder = OrderRecorder()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["X-Resp": "1"])!
            return (response, Data())
        }

        let config = HttpClientConfig()
        config.onResponse { response in
            responseOrder.append("first")
            seenType.set(String(describing: type(of: response.request)))
            seenHeader.set(response.request.getHeader(name: "x-requested-with") ?? "")
        }
        config.onResponse { _ in
            responseOrder.append("second")
            expectation.fulfill()
        }

        let client = makeClient(config: config)
        _ = await client.request { req in
            guard let mutable = req as? URLSessionHttpRequest else { return }
            mutable.url = "https://example.com"
            mutable.setHeader(name: "X-Custom", value: "yes")
            mutable.get()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(responseOrder.snapshot(), ["first", "second"])
        XCTAssertEqual(seenHeader.snapshot(), "ping-sdk")
        XCTAssertTrue(seenType.snapshot()?.contains("ImmutableHttpRequest") == true)
    }

    private func makeClient(config: HttpClientConfig = HttpClientConfig()) -> URLSessionHttpClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        return URLSessionHttpClient(config: config, session: session, delegate: nil)
    }
}

final class ValueRecorder<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T?

    func set(_ value: T) {
        lock.lock()
        self.value = value
        lock.unlock()
    }

    func snapshot() -> T? {
        lock.lock()
        let current = value
        lock.unlock()
        return current
    }
}
