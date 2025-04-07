// 
//  CallbackFactoryTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

class CallbackFactoryTests: XCTestCase {
    override func setUp() async throws{
        await CollectorFactory.shared.register(type: "type1", collector: DummyCallback.self)
        await CollectorFactory.shared.register(type: "type2", collector: Dummy2Callback.self)
    }
    
    func testShouldReturnListOfCollectorsWhenValidTypesAreProvided() async {
        let jsonArray: [[String: Any]] = [
            ["type": "type1"],
            ["type": "type2"]
        ]
        
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        XCTAssertEqual((callbacks[0] as? DummyCallback)?.value, "dummy")
        XCTAssertEqual((callbacks[1] as? Dummy2Callback)?.value, "dummy2")
        
        XCTAssertEqual(callbacks.count, 2)
    }
    
    func testShouldReturnEmptyListWhenNoValidTypesAreProvided() async {
        let jsonArray: [[String: Any]] = [
            ["type": "invalidType"]
        ]
        
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
    
    func testShouldReturnEmptyListWhenJsonArrayIsEmpty() async {
        let jsonArray: [[String: Any]] = []
        
        let callbacks = await CollectorFactory.shared.collector(from: jsonArray)
        
        XCTAssertTrue(callbacks.isEmpty)
    }
}

public class DummyCallback: Collector, @unchecked Sendable {
    public typealias T = String
    
    public var id: String {
        return UUID().uuidString
    }
    let value: String?
    
    required public init(with json: [String: Any]) {
        value = "dummy"
    }
}

final class Dummy2Callback: Collector {
    public typealias T = String
    
    public var id: String {
        return UUID().uuidString
    }
    let value: String?
    
    required public init(with json: [String: Any]) {
        value = "dummy2"
    }
}
