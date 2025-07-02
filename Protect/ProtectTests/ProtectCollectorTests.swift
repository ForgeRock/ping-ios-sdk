//
//  ProtectCollectorTests.swift
//  Protect
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingProtect

class ProtectCollectorTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testInitSetsAllPropertiesFromJson() throws {
        // Given
        let jsonString = """
        {
            "key": "riskKey",
            "behavioralDataCollection": false,
            "universalDeviceIdentification": true
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        
        // When
        let collector = ProtectCollector(with: jsonObject)
        
        
        // Then
        XCTAssertEqual(collector.key, "riskKey")
        XCTAssertFalse(collector.behavioralDataCollection)
        XCTAssertTrue(collector.universalDeviceIdentification)
    }
    
    func testInitUsesDefaultsWhenFieldsMissing() {
        // Given
        let emptyJson: [String: Any] = [:]
        
        // When
        let collector = ProtectCollector(with: emptyJson)
        
        // Then
        XCTAssertEqual(collector.key, "")
        XCTAssertTrue(collector.behavioralDataCollection)
        XCTAssertFalse(collector.universalDeviceIdentification)
    }
    
    func testIdReturnsKey() {
        // Given
        let json = ["key": "abc"]
        
        // When
        let collector = ProtectCollector(with: json)
        
        // Then
        XCTAssertEqual(collector.id, "abc")
    }
    
    func testPayloadReturnsNilWhenValueIsEmpty() {
        // Given
        let collector = ProtectCollector(with: [:])
        
        // When & Then
        XCTAssertNil(collector.payload())
    }
    
    func testCollectReturnsSuccessWithData() async throws {
        // Given
        let collector = ProtectCollector(with: [:])
        
        // When
        let result = await collector.collect()
        
        // Then
        switch result {
        case .success(let data):
            XCTAssertNotNil(data)
            XCTAssertEqual(data, collector.payload())
        case .failure:
            XCTFail("Expected success but got failure")
        }
    }
}
