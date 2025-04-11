// 
//  SingleSelectCollectorTests.swift
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

final class SingleSelectCollectorTests: XCTestCase {
    
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
        
        let collector = SingleSelectCollector(with: input)
        
        XCTAssertEqual(
            collector.options.map { $0.label },
            ["Option 1", "Option 2"]
        )
        XCTAssertEqual(
            collector.options.map { $0.value },
            ["Option 1 Value", "Option 2 Value"]
        )
    }
    
    func testInitializesValueWithProvidedJsonElement() {
        let input = "Selected Option"
        let collector = SingleSelectCollector(with: [:])
        collector.initialize(with: input)
        
        XCTAssertEqual(collector.value, "Selected Option")
    }
    
    func testInitializesOptionsWithEmptyListWhenNoValueProvided() {
        let input: [String: Any] = [:]
        let collector = SingleSelectCollector(with: input)
        
        XCTAssertEqual(collector.options.count, 0)
    }
}
