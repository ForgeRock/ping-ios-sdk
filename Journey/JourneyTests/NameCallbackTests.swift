//
//  NameCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

import XCTest
@testable import PingJourney

final class NameCallbackTests: XCTestCase {
    
    func testInitWithValidDictionary() {
        let dictionary: [String: Any] = [
            "type": "NameCallback",
            "output": [
                [
                    "name": "prompt",
                    "value": "User Name"
                ]
            ],
            "input": [
                [
                    "name": "IDToken1",
                    "value": ""
                ]
            ],
            "_id": 0
        ]
        
        let callback = NameCallback(with: dictionary)
        XCTAssertEqual(callback.prompt, "User Name")
        XCTAssertEqual(callback.json["type"] as? String, "NameCallback")
    }
    
    func testInitWithEmptyDictionary() {
        let callback = NameCallback(with: [:])
        XCTAssertEqual(callback.prompt, "")
        XCTAssertTrue(callback.payload().isEmpty)
    }
    
    func testSetName() {
        let callback = NameCallback(with: [
            "input": [
                [
                    "name": "IDToken1",
                    "value": ""
                ]
            ]
        ])
        
        callback.name = "john.doe"
        let payload = callback.payload()
        let input = (payload["input"] as? [[String: Any]])?.first
        XCTAssertEqual(input?["value"] as? String, "john.doe")
    }
    
    func testPayloadGeneration() {
        let callback = NameCallback(with: [
            "input": [
                [
                    "name": "IDToken1",
                    "value": ""
                ]
            ]
        ])
        
        callback.name = "john.doe"
        let payload = callback.payload()
        
        XCTAssertNotNil(payload["input"] as? [[String: Any]])
        let input = (payload["input"] as? [[String: Any]])?.first
        XCTAssertEqual(input?["name"] as? String, "IDToken1")
        XCTAssertEqual(input?["value"] as? String, "john.doe")
    }
    
    func testCompleteCallbackFlow() {
        let dictionary: [String: Any] = [
            "type": "NameCallback",
            "output": [
                [
                    "name": "prompt",
                    "value": "User Name"
                ]
            ],
            "input": [
                [
                    "name": "IDToken1",
                    "value": ""
                ]
            ],
            "_id": 0
        ]
        
        let callback = NameCallback(with: dictionary)
        XCTAssertEqual(callback.prompt, "User Name")
        
        callback.name = "john.doe"
        let payload = callback.payload()
        let input = (payload["input"] as? [[String: Any]])?.first
        
        XCTAssertEqual(input?["name"] as? String, "IDToken1")
        XCTAssertEqual(input?["value"] as? String, "john.doe")
    }
}
