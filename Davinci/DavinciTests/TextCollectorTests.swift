// 
//  TextCollectorTests.swift
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

final class TextCollectorTests: XCTestCase {
    
    func testInitialization() {
        let textCollector = TextCollector(with: [:])
        XCTAssertNotNil(textCollector)
    }
    
    func testShouldInitializeKeyAndLabelFromDictionary() {
        let input: [String: Any] = [
            "key": "testKey",
            "label": "testLabel"
        ]
        
        let textCollector = TextCollector(with: input)
        
        XCTAssertEqual(textCollector.key, "testKey")
        XCTAssertEqual(textCollector.label, "testLabel")
    }
    
    func testShouldReturnValueWhenValueIsSet() {
        let textCollector = TextCollector(with: [:])
        textCollector.value = "test"
        
        XCTAssertEqual(textCollector.value, "test")
    }
    
    func testShouldInitializeDefaultValue() {
        let input = "test"
        let textCollector = TextCollector(with: [:])
        textCollector.initialize(with: input)
        
        XCTAssertEqual(textCollector.value, "test")
    }
}
