//
//  URLSessionHttpRequestTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class URLSessionHttpRequestTests: XCTestCase {
    func testURLAndQueryParameters() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com/path"
        request.setParameter(name: "q", value: "test")
        request.setParameter(name: "lang", value: "en")

        let built = request.buildURLRequest()
        XCTAssertEqual(built?.url?.absoluteString, "https://example.com/path?q=test&lang=en")
    }

    func testHeaderLookupIsCaseInsensitive() {
        let request = URLSessionHttpRequest()
        request.setHeader(name: NetworkConstants.headerContentType, value: NetworkConstants.contentTypeJSON)
        XCTAssertEqual(request.getHeader(name: "content-type"), NetworkConstants.contentTypeJSON)
    }

    func testDefaultStandardHeaders() {
        let request = URLSessionHttpRequest()
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerRequestedWith), NetworkConstants.requestedWithValue)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerRequestedPlatform), NetworkConstants.requestedPlatformValue)
    }

    func testCookiesAggregated() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"
        request.setCookie(cookie: "a=1")
        request.setCookies(cookies: ["b=2", "c=3"])

        let built = request.buildURLRequest()
        XCTAssertEqual(built?.value(forHTTPHeaderField: "Cookie"), "a=1; b=2; c=3")
    }

    func testJsonMethodsAndBodies() throws {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"

        request.post(json: ["a": 1])
        XCTAssertEqual(request.getMethod(), .post)
        let postBody = try XCTUnwrap(request.buildURLRequest()?.httpBody)
        let postJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: postBody) as? [String: Int])
        XCTAssertEqual(postJSON, ["a": 1])
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerContentType), NetworkConstants.contentTypeJSON)

        request.put(json: ["b": "2"])
        XCTAssertEqual(request.getMethod(), .put)
        let putBody = try XCTUnwrap(request.buildURLRequest()?.httpBody)
        let putJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: putBody) as? [String: String])
        XCTAssertEqual(putJSON, ["b": "2"])

        request.delete(json: ["c": true])
        XCTAssertEqual(request.getMethod(), .delete)
        let deleteBody = try XCTUnwrap(request.buildURLRequest()?.httpBody)
        let deleteJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: deleteBody) as? [String: Bool])
        XCTAssertEqual(deleteJSON, ["c": true])
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerContentType), NetworkConstants.contentTypeJSON)

        request.post(json: [:])
        let emptyBody = try XCTUnwrap(request.buildURLRequest()?.httpBody)
        let emptyJSON = try XCTUnwrap(try JSONSerialization.jsonObject(with: emptyBody) as? [String: Any])
        XCTAssertTrue(emptyJSON.isEmpty)

        request.post(contentType: "text/plain", body: "hello")
        XCTAssertEqual(request.getMethod(), .post)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerContentType), "text/plain")
        XCTAssertEqual(request.buildURLRequest()?.httpBody, Data("hello".utf8))

        request.put(contentType: "text/plain", body: "update")
        XCTAssertEqual(request.getMethod(), .put)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerContentType), "text/plain")
        XCTAssertEqual(request.buildURLRequest()?.httpBody, Data("update".utf8))

        request.delete(contentType: "text/plain", body: "remove")
        XCTAssertEqual(request.getMethod(), .delete)
        XCTAssertEqual(request.getHeader(name: NetworkConstants.headerContentType), "text/plain")
        XCTAssertEqual(request.buildURLRequest()?.httpBody, Data("remove".utf8))
    }

    func testFormAccumulationSetsBodyAndContentType() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"
        request.form(parameters: ["a": "1"])
        request.form(parameters: ["b": "2"])
        request.form(parameters: ["a": "3"])

        let built = request.buildURLRequest()
        let bodyString = String(data: built?.httpBody ?? Data(), encoding: .utf8)
        XCTAssertEqual(bodyString, "a=1&b=2&a=3")
        XCTAssertEqual(built?.value(forHTTPHeaderField: NetworkConstants.headerContentType), NetworkConstants.contentTypeForm)
    }

    func testInvalidURLStringReturnsNil() {
        let request = URLSessionHttpRequest()
        request.url = "ht tp://invalid"
        XCTAssertNil(request.buildURLRequest())
    }
}
