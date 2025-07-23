//
//  PasswordCallbackTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

final class PasswordCallbackTests: XCTestCase {
    
    func testInitWithValidDictionary() {
        let dictionary: [String: Any] = [
            "type": "PasswordCallback",
            "output": [
                [
                    "name": "prompt",
                    "value": "Password"
                ]
            ],
            "input": [
                [
                    "name": "IDToken2",
                    "value": ""
                ]
            ],
            "_id": 1
        ]
        
        let callback = PasswordCallback()
        _ = callback.initialize(with: dictionary)
        XCTAssertEqual(callback.prompt, "Password")
        XCTAssertEqual(callback.json["type"] as? String, "PasswordCallback")
    }
    
    func testInitWithEmptyDictionary() {
        let callback = PasswordCallback()
        _ = callback.initialize(with: [:])
        XCTAssertEqual(callback.prompt, "")
        XCTAssertTrue(callback.payload().isEmpty)
    }
    
    func testSetPassword() {
        let callback = PasswordCallback()
        _ = callback.initialize(with: [
            "input": [
                [
                    "name": "IDToken2",
                    "value": ""
                ]
            ]
        ])
        
        callback.password = "secretPass123"
        let payload = callback.payload()
        let input = (payload["input"] as? [[String: Any]])?.first
        XCTAssertEqual(input?["value"] as? String, "secretPass123")
    }
    
    func testPayloadGeneration() {
        let callback = PasswordCallback()
        _ = callback.initialize(with: [
            "input": [
                [
                    "name": "IDToken2",
                    "value": ""
                ]
            ]
        ])
        
        callback.password = "secretPass123"
        let payload = callback.payload()
        
        XCTAssertNotNil(payload["input"] as? [[String: Any]])
        let input = (payload["input"] as? [[String: Any]])?.first
        XCTAssertEqual(input?["name"] as? String, "IDToken2")
        XCTAssertEqual(input?["value"] as? String, "secretPass123")
    }
    
    func testCompleteCallbackFlow() {
        let dictionary: [String: Any] = [
            "type": "PasswordCallback",
            "output": [
                [
                    "name": "prompt",
                    "value": "Password"
                ]
            ],
            "input": [
                [
                    "name": "IDToken2",
                    "value": ""
                ]
            ],
            "_id": 1
        ]
        
        let callback = PasswordCallback()
        _ = callback.initialize(with: dictionary)
        XCTAssertEqual(callback.prompt, "Password")
        
        callback.password = "secretPass123"
        let payload = callback.payload()
        let input = (payload["input"] as? [[String: Any]])?.first
        
        XCTAssertEqual(input?["name"] as? String, "IDToken2")
        XCTAssertEqual(input?["value"] as? String, "secretPass123")
    }
}
