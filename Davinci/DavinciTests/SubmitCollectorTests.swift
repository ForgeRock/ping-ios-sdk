// 
//  SubmitCollectorTests.swift
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

final class SubmitCollectorTests: XCTestCase {
    
    func testInitialization() {
        let submitCollector = SubmitCollector(with: [:])
        XCTAssertNotNil(submitCollector)
    }
    
    func testCloseShouldClearValue() {
        let submitCollector = SubmitCollector(with: [:])
        submitCollector.value = "submitValue"
        
        XCTAssertEqual("submitValue", submitCollector.value)
        XCTAssertEqual("submitValue", submitCollector.payload())
        
        submitCollector.close()
        
        XCTAssertEqual("", submitCollector.value)
        XCTAssertNil(submitCollector.payload())
    }
    
    func testCloseShouldAllowReuse() {
        let submitCollector = SubmitCollector(with: [:])
        
        submitCollector.value = "submit1"
        XCTAssertEqual("submit1", submitCollector.payload())
        
        submitCollector.close()
        XCTAssertEqual("", submitCollector.value)
        
        submitCollector.value = "submit2"
        XCTAssertEqual("submit2", submitCollector.payload())
    }
}
