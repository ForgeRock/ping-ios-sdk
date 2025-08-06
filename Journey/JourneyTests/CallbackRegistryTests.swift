//
//  CallbackRegistryTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingJourney

class CustomCallback: AbstractCallback, @unchecked Sendable {
    /// The prompt message displayed to the user for input.
    private(set) public var prompt: String = ""
    /// The name of the input field.
    public var name: String = ""
    
    /// Initializes a new instance of `NameCallback` with the provided JSON input.
    public override func initValue(name: String, value: Any) {
        if name == "prompt", let stringValue = value as? String {
            self.prompt = stringValue
        }
    }
    
    /// Returns the payload with the name value.
    public override func payload() -> [String: Any] {
        return input(name)
    }
}


final class CallbackRegistryTests: XCTestCase {
    
    func testRegisterAndRetrieveCallback() async {
        let registry = CallbackRegistry()
        let key = "customCallback"
        registry.register(type: key, callback: CustomCallback.self)
        let callbackType = registry.callbacks[key]
        XCTAssertNotNil(callbackType)
        XCTAssertTrue(callbackType is CustomCallback.Type)
    }
    
    func testCallbackNotFound() async {
        let registry = CallbackRegistry()
        let callbackType = registry.callbacks["nonexistent"]
        XCTAssertNil(callbackType)
    }
    
    func testClearAllCallbacks() async {
        let registry = CallbackRegistry()
        registry.register(type: "key1", callback: CustomCallback.self)
        registry.register(type: "key2", callback: CustomCallback.self)
        registry.reset()
        let count = registry.callbacks.count
        XCTAssertTrue(count == 0)
    }
    
    func testMultipleCallbackTypes() async {
        let registry = CallbackRegistry()
        class AnotherCallback: AbstractCallback, @unchecked Sendable {
            /// The prompt message displayed to the user for input.
            private(set) public var prompt: String = ""
            /// The name of the input field.
            public var name: String = ""
            
            /// Initializes a new instance of `NameCallback` with the provided JSON input.
            public override func initValue(name: String, value: Any) {
                if name == "prompt", let stringValue = value as? String {
                    self.prompt = stringValue
                }
            }
            
            /// Returns the payload with the name value.
            public override func payload() -> [String: Any] {
                return input(name)
            }
        }
        registry.register(type: "type1", callback: CustomCallback.self)
        registry.register(type: "type2", callback: AnotherCallback.self)
        let type1 = registry.callbacks["type1"]
        let type2 = registry.callbacks["type2"]
        XCTAssertNotNil(type1)
        XCTAssertNotNil(type2)
        XCTAssertTrue(type1 is CustomCallback.Type)
        XCTAssertTrue(type2 is AnotherCallback.Type)
    }
    
}
