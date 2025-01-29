// 
//  MultiSelectCollectorTests.swift
//  DavinciTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

final class MultiSelectCollectorTests: XCTestCase {
    
    func testInitializesOptionsWithProvidedValue() {
        let input: [String: Any] = [
            "options": [
                [
                    "label": "Option 1",
                    "value": "Option 1 Value"
                ],
                [
                    "label": "Option 2",
                    "value": "Option 2 Value"
                ]
            ]
        ]
        
        let collector = MultiSelectCollector(with: input)
        
        XCTAssertEqual(
            collector.options.map { $0.label },
            ["Option 1", "Option 2"]
        )
        XCTAssertEqual(
            collector.options.map { $0.value },
            ["Option 1 Value", "Option 2 Value"]
        )
    }
    
    func testInitializesOptionsWithEmptyListWhenNoValueProvided() {
        let input: [String: Any] = [:]
        let collector = MultiSelectCollector(with: input)
        
        XCTAssertEqual(collector.options.count, 0)
    }
    
    func testAddsRequiredErrorWhenValueIsEmptyAndRequired() {
        let input: [String: Any] = [
            "required": true
        ]
        let collector = MultiSelectCollector(with: input)
        
        XCTAssertEqual(collector.validate(), [.required])
    }
    
    func testDoesNotAddRequiredErrorWhenValueIsNotEmptyAndRequired() {
        let input: [String: Any] = [
            "required": true
        ]
        let inputDefault = "Selected Option"
        let collector = MultiSelectCollector(with: input)
        collector.initialize(with: inputDefault)
        
        XCTAssertEqual(collector.validate(), [])
    }
    
    func testDoesNotAddRequiredErrorWhenValueIsArrayAndRequired() {
        let input: [String: Any] = [
            "required": true
        ]
        let inputDefault = ["Selected Option"]
        let collector = MultiSelectCollector(with: input)
        collector.initialize(with: inputDefault)
        
        XCTAssertEqual(collector.validate(), [])
    }
}
