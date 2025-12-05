//
//  URLSessionHttpResponseTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class URLSessionHttpResponseTests: XCTestCase {
    func testStatusHeadersAndBody() {
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            status: 200,
            headers: ["Content-Type": ["application/json"]],
            body: Data("{\"ok\":true}".utf8),
            httpURLResponse: nil
        )

        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.getHeader(name: "content-type"), "application/json")
        XCTAssertEqual(response.bodyAsString(), "{\"ok\":true}")
    }

    func testCookiesExtraction() {
        let url = URL(string: "https://example.com")!
        let request = URLSessionHttpRequest()
        request.url = url.absoluteString
        let response = URLSessionHttpResponse(
            request: request,
            status: 200,
            headers: ["Set-Cookie": ["a=1; Path=/\nb=2; Path=/"]],
            body: nil,
            httpURLResponse: nil
        )

        let cookies = response.getCookies()
        XCTAssertEqual(cookies.count, 2)
        let names = cookies.map(\.name).sorted()
        XCTAssertEqual(names, ["a", "b"])
    }

    func testMultiValueHeaders() {
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            status: 200,
            headers: ["Set-Cookie": ["a=1", "b=2"], "X-Test": ["1", "2"]],
            body: nil,
            httpURLResponse: nil
        )

        XCTAssertEqual(response.getHeader(name: "x-test"), "1")
        XCTAssertEqual(response.getHeaders(name: "X-Test"), ["1", "2"])
        XCTAssertEqual(response.getCookieStrings().sorted(), ["a=1", "b=2"])
    }
}
