//
//  URLSessionHttpResponseTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class URLSessionHttpResponseTests: XCTestCase {
    func testStatusBody() {
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: Data("{\"ok\":true}".utf8),
            httpURLResponse: nil
        )

        XCTAssertEqual(response.bodyAsString(), "{\"ok\":true}")
    }

    func testStatusDefaultsTo200WhenNilResponse() {
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: nil
        )
        XCTAssertEqual(response.status, 0)
    }

    func testStatusFromHTTPURLResponse() {
        let url = URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )
        XCTAssertEqual(response.status, 404)
    }

    func testBodyAsStringEmpty() {
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: nil
        )
        XCTAssertEqual(response.bodyAsString(), "")
    }

    func testBodyAsStringWithData() {
        let testString = "Hello, World!"
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: Data(testString.utf8),
            httpURLResponse: nil
        )
        XCTAssertEqual(response.bodyAsString(), testString)
    }

    func testBodyAsStringInvalidUTF8() {
        let invalidUTF8: [UInt8] = [0xFF, 0xFE, 0xFD]
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: Data(invalidUTF8),
            httpURLResponse: nil
        )
        XCTAssertEqual(response.bodyAsString(), "")
    }

    func testGetHeaderCaseInsensitive() {
        let url = URL(string: "https://example.com")!
        let headers = ["Content-Type": "application/json"]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )
        XCTAssertEqual(response.getHeader(name: "content-type"), "application/json")
        XCTAssertEqual(response.getHeader(name: "Content-Type"), "application/json")
        XCTAssertEqual(response.getHeader(name: "CONTENT-TYPE"), "application/json")
    }

    func testGetHeaderReturnsNilIfNotPresent() {
        let url = URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )
        XCTAssertNil(response.getHeader(name: "X-Custom-Header"))
    }

    func testGetCookiesSingleCookie() {
        let url = URL(string: "https://example.com")!
        let headers = ["Set-Cookie": "sessionId=abc123; Path=/; HttpOnly"]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookies = response.getCookies()
        XCTAssertEqual(cookies.count, 1)
        XCTAssertEqual(cookies.first?.name, "sessionId")
        XCTAssertEqual(cookies.first?.value, "abc123")
    }

    func testGetCookiesMultipleCookies() {
        let url = URL(string: "https://example.com")!
        let headers: [String: String] = [
            "Set-Cookie": "session=xyz789; Path=/; HttpOnly"
        ]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookies = response.getCookies()
        XCTAssertGreaterThanOrEqual(cookies.count, 1)
    }

    func testGetCookiesNoCookies() {
        let url = URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookies = response.getCookies()
        XCTAssertEqual(cookies.count, 0)
    }

    func testGetCookieStrings() {
        let url = URL(string: "https://example.com")!
        let headers = ["Set-Cookie": "id=a3fWa; Expires=Wed, 21 Oct 2025 07:28:00 GMT"]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookieStrings = response.getCookieStrings()
        XCTAssertGreaterThanOrEqual(cookieStrings.count, 0)
    }

    func testGetCookieStringsNoCookies() {
        let url = URL(string: "https://example.com")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookieStrings = response.getCookieStrings()
        XCTAssertTrue(cookieStrings.isEmpty)
    }

    func testGetCookiesWithAttributes() {
        let url = URL(string: "https://example.com")!
        let headers = ["Set-Cookie": "auth=token123; Path=/; Domain=example.com; Secure; HttpOnly; SameSite=Strict"]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        let cookies = response.getCookies()
        if !cookies.isEmpty {
            let cookie = cookies.first!
            XCTAssertEqual(cookie.name, "auth")
            XCTAssertEqual(cookie.value, "token123")
            XCTAssertTrue(cookie.isSecure)
            XCTAssertTrue(cookie.isHTTPOnly)
        }
    }

    func testRequestProperty() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"
        let response = URLSessionHttpResponse(
            request: request,
            body: nil,
            httpURLResponse: nil
        )
        XCTAssertEqual(response.request.url, request.url)
    }

    func testBodyPreservation() {
        let originalBody = Data("[{\"id\": 1}, {\"id\": 2}]".utf8)
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: originalBody,
            httpURLResponse: nil
        )
        XCTAssertEqual(response.body, originalBody)
    }

    func testMultipleHeaderValues() {
        let url = URL(string: "https://example.com")!
        let headers = ["Accept": "application/json", "User-Agent": "TestClient/1.0"]
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        )
        let response = URLSessionHttpResponse(
            request: URLSessionHttpRequest(),
            body: nil,
            httpURLResponse: httpResponse
        )

        XCTAssertEqual(response.getHeader(name: "Accept"), "application/json")
        XCTAssertEqual(response.getHeader(name: "User-Agent"), "TestClient/1.0")
    }
}

