// 
//  FieldCollectorTests.swift
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

class FieldCollectorTests: XCTestCase {
    
    func testShouldInitializeKeyAndLabelFromJsonObject() {
        
        let jsonObject: [String: String] = [
            "type": "testType",
            "key": "testKey",
            "label": "testLabel"
        ]
        
        let fieldCollector = FieldCollector<String>(with: jsonObject)
        
        XCTAssertEqual("testType", fieldCollector.type)
        XCTAssertEqual("testKey", fieldCollector.key)
        XCTAssertEqual("testLabel", fieldCollector.label)
    }
    
    func testShouldReturnValueWhenValueIsSet() {
        let fieldCollector = SingleValueCollector(with: [:])
        fieldCollector.value = "test"
        XCTAssertEqual("test", fieldCollector.value)
    }
}
