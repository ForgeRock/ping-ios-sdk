//
//  CollectorRegistryTests.swift
//  DavinciTests
//
//  Copyright (c) 2024 - 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import XCTest
@testable import PingDavinci

final class CollectorRegistryTests: XCTestCase {
    
    private var collectorFactory: CollectorFactory!
    
    override func setUp() {
        super.setUp()
        collectorFactory = CollectorFactory()
        collectorFactory.registerDefaultCollectors()
    }
    
    override func tearDown() {
        super.tearDown()
        collectorFactory.reset()
    }
    
    func testShouldRegisterCollector() {
        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["inputType": "ACTION"],
            ["type": "PASSWORD_VERIFY"],
            ["inputType": "ACTION"],
            ["type": "LABEL"],
            ["inputType": "SINGLE_SELECT"],
            ["inputType": "SINGLE_SELECT"],
            ["inputType": "MULTI_SELECT"],
            ["inputType": "MULTI_SELECT"],
        ]
        
        let collectors = collectorFactory.collector(from: jsonArray)
        XCTAssertTrue(collectors[0] is TextCollector)
        XCTAssertTrue(collectors[1] is PasswordCollector)
        XCTAssertTrue(collectors[2] is SubmitCollector)
        XCTAssertTrue(collectors[3] is FlowCollector)
        XCTAssertTrue(collectors[4] is PasswordCollector)
        XCTAssertTrue(collectors[5] is FlowCollector)
        XCTAssertTrue(collectors[6] is LabelCollector)
        XCTAssertTrue(collectors[7] is SingleSelectCollector)
        XCTAssertTrue(collectors[8] is SingleSelectCollector)
        XCTAssertTrue(collectors[9] is MultiSelectCollector)
        XCTAssertTrue(collectors[10] is MultiSelectCollector)
    }
    
    func testShouldIgnoreUnknownCollector() {
        let jsonArray: [[String: Any]] = [
            ["type": "TEXT"],
            ["type": "PASSWORD"],
            ["type": "SUBMIT_BUTTON"],
            ["inputType": "ACTION"],
            ["type": "UNKNOWN"]
        ]
        
        let collectors = collectorFactory.collector(from: jsonArray)
        XCTAssertEqual(collectors.count, 4)
    }
}
