//
//  PingBinderTests.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingBinding
@testable import PingJourney

class PingBinderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Task {
            let storage = UserKeysStorage(config: UserKeyStorageConfig())
            try? storage.deleteByUserId("testUser")
        }
    }
    
    override func tearDown() {
        super.tearDown()
        Task {
            let storage = UserKeysStorage(config: UserKeyStorageConfig())
            try? storage.deleteByUserId("testUser")
        }
    }

    func testBind() {
        // Given
        let callback = DeviceBindingCallback()
        callback.userId = "testUser"
        callback.challenge = "testChallenge"
        
        // When
        let expectation = self.expectation(description: "Bind completes")
        Task {
            do {
                let jws = try await PingBinder.bind(callback: callback, journey: nil)
                XCTAssertNotNil(jws)
                
                let callbackJws = (callback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == "jws" })?["value"]
                XCTAssertNotNil(callbackJws)
                XCTAssertEqual(jws, callbackJws as? String)
                
                expectation.fulfill()
            } catch {
                XCTFail("Bind failed with error: \(error)")
            }
        }
        
        // Then
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testSign() {
        // Given
        let bindCallback = DeviceBindingCallback()
        bindCallback.userId = "testUser"
        bindCallback.challenge = "testChallenge"
        
        let expectation = self.expectation(description: "Bind and Sign completes")
        Task {
            do {
                _ = try await PingBinder.bind(callback: bindCallback, journey: nil)
                
                let signCallback = DeviceSigningVerifierCallback()
                signCallback.userId = "testUser"
                signCallback.challenge = "testChallenge"
                
                // When
                let jws = try await PingBinder.sign(callback: signCallback, journey: nil)
                XCTAssertNotNil(jws)
                
                // Then
                let callbackJws = (signCallback.json[JourneyConstants.input] as? [[String: Any]])?.first(where: { $0[JourneyConstants.name] as? String == "jws" })?["value"]
                XCTAssertNotNil(callbackJws)
                XCTAssertEqual(jws, callbackJws as? String)
                
                expectation.fulfill()
            } catch {
                XCTFail("Sign failed with error: \(error)")
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
}
