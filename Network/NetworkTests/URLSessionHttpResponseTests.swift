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
}
