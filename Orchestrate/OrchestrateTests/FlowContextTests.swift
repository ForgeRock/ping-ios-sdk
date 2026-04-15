//
//  FlowContextTests.swift
//  OrchestrateTests
//
//  Copyright (c) 2024 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingOrchestrate
@testable import PingNetwork

final class FlowContextTests: XCTestCase {
    
    func testInit() async throws {
        let context = FlowContext(flowContext: SharedContext(["cookie": "pingCookie"]))
        XCTAssertNotNil(context)
    }
    
    func testDefaultValues() async throws {
        let context = FlowContext(flowContext: SharedContext(["cookie": "pingCookie"]))
        let  request = HttpClient.createClient().request()
        let body = ["bodykey": "bodyvalue"]
        request.url = "https://pingone.com"
        request.setHeader(name: "testHeader", value: "testValue")
        request.setHeader(name: "testHeader1", value: "testValue2")
        request.setHeader(name: "testHeader1", value: "testValue2")
        request.setParameter(name: "key1", value: "key1Value")
        request.setParameter(name: "key2", value: "key2Value")
        request.post(json: body)
        
        context.flowContext.set(key: "request", value: request)
        let cookie = context.flowContext.get(key: "cookie")
        XCTAssertNotNil(cookie)
        let requestValue = context.flowContext.get(key: "request")
        XCTAssertTrue(requestValue != nil)
        XCTAssertTrue(requestValue is Request)
    }
}
