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

    func testURLPropertyGetterReturnsurlRequestURL() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com/api"
        XCTAssertEqual(request.url, "https://example.com/api")
    }

    func testURLPropertySetterUpdatesurlRequestURL() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"
        request.url = "https://different.com/path"
        XCTAssertEqual(request.url, "https://different.com/path")
        XCTAssertEqual(request.buildURLRequest()?.url?.absoluteString, "https://different.com/path")
    }

    func testURLPropertySyncWithQueryParameters() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com/api"
        request.setParameter(name: "key", value: "value")
        
        // url getter returns urlRequest.url which includes query parameters
        XCTAssertEqual(request.url, "https://example.com/api?key=value")
        
        // Building the request should have the same complete URL
        XCTAssertEqual(request.buildURLRequest()?.url?.absoluteString, "https://example.com/api?key=value")
    }

    func testURLPropertyAfterMultipleParameterUpdates() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com"
        request.setParameter(name: "a", value: "1")
        request.setParameter(name: "b", value: "2")
        request.setParameter(name: "c", value: "3")
        
        // URL getter reflects urlRequest.url which includes all parameters
        XCTAssertEqual(request.url, "https://example.com?a=1&b=2&c=3")
        
        // Built request should have all parameters
        let built = request.buildURLRequest()
        XCTAssertEqual(built?.url?.absoluteString, "https://example.com?a=1&b=2&c=3")
    }

    func testURLPropertyInvalidStringDoesNotUpdateurlRequest() {
        let request = URLSessionHttpRequest()
        request.url = "https://valid.com"
        XCTAssertEqual(request.url, "https://valid.com")
        
        // Set to invalid URL
        request.url = "ht tp://invalid"
        
        // URL should be nil after setting invalid string
        XCTAssertNil(request.url)
    }

    func testURLPropertyWithComplexPath() {
        let request = URLSessionHttpRequest()
        request.url = "https://example.com/api/v1/users/123/profile"
        XCTAssertEqual(request.url, "https://example.com/api/v1/users/123/profile")
        
        request.setParameter(name: "include", value: "metadata")
        let built = request.buildURLRequest()
        XCTAssertEqual(built?.url?.absoluteString, "https://example.com/api/v1/users/123/profile?include=metadata")
    }
}
