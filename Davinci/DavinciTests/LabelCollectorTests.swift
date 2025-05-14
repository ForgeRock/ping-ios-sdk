// 
//  LabelCollectorTests.swift
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

class LabelCollectorTests: XCTestCase {
    
    func testInitializesContentWithProvidedValue() {
        
        let jsonObject: [String: String] = [
            "content": "Test Content",
            "key": "Test Key",
        ]
        
        let labelCollector = LabelCollector(with: jsonObject)
        
        XCTAssertEqual("Test Content", labelCollector.content)
        XCTAssertEqual("Test Key", labelCollector.key)
    }
    
    func testInitializesContentWithEmptyStringWhenNoValueProvided() {
        
        let jsonObject: [String: String] = [:]
        
        let labelCollector = LabelCollector(with: jsonObject)
        
        XCTAssertEqual("", labelCollector.content)
    }
}
