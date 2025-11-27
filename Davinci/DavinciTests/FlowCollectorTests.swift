// 
//  FlowCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

class FlowCollectorTests: XCTestCase {
    
    func testShouldInitializeKeyAndLabelFromJsonObject() {
        
        let jsonObject: [String: String] = [
            "type": "testType",
            "key": "testKey",
            "label": "testLabel"
        ]
        
        let flowCollector = FlowCollector(with: jsonObject)
        
        XCTAssertEqual("testType", flowCollector.type)
        XCTAssertEqual("testKey", flowCollector.key)
        XCTAssertEqual("testLabel", flowCollector.label)
    }
    
    func testShouldReturnValueWhenValueIsSet() {
        let fieldCollector = SingleValueCollector(with: [:])
        fieldCollector.value = "test"
        XCTAssertEqual("test", fieldCollector.value)
    }
    
    func testCloseShouldClearValue() {
        let flowCollector = FlowCollector(with: [:])
        flowCollector.value = "testValue"
        
        XCTAssertEqual("testValue", flowCollector.value)
        XCTAssertEqual("testValue", flowCollector.payload())
        
        flowCollector.close()
        
        XCTAssertEqual("", flowCollector.value)
        XCTAssertNil(flowCollector.payload())
    }
    
    func testCloseShouldAllowReuse() {
        let flowCollector = FlowCollector(with: [:])
        
        flowCollector.value = "value1"
        XCTAssertEqual("value1", flowCollector.payload())
        
        flowCollector.close()
        XCTAssertEqual("", flowCollector.value)
        
        flowCollector.value = "value2"
        XCTAssertEqual("value2", flowCollector.payload())
    }
}
