//
//  HttpClientFactoryTests.swift
//  PingNetworkTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingNetwork

final class HttpClientFactoryTests: XCTestCase {
    func testCreateClientWithDefaultConfiguration() {
        let client = HttpClient.createClient()
        XCTAssertNotNil(client)
        client.close()
    }

    func testCreateClientWithCustomConfiguration() {
        let client = HttpClient.createClient { config in
            config.timeout = 30.0
        }
        XCTAssertNotNil(client)
        client.close()
    }

    func testCreateClientReturnsHttpClientProtocol() {
        let client: any HttpClientProtocol = HttpClient.createClient()
        XCTAssertNotNil(client)
        client.close()
    }

    func testURLSessionHttpClientConformsToProtocol() {
        let client: any HttpClientProtocol = URLSessionHttpClient.createClient()
        XCTAssertNotNil(client)
        client.close()
    }
}
