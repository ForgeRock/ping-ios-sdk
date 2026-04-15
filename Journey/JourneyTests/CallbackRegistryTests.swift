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
@testable import PingJourneyPlugin
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
        await registry.register(type: key, callback: CustomCallback.self)
        let callbackType = await registry.callbacks[key]
        XCTAssertNotNil(callbackType)
        XCTAssertTrue(callbackType is CustomCallback.Type)
    }
    
    func testCallbackNotFound() async {
        let registry = CallbackRegistry()
        let callbackType = await registry.callbacks["nonexistent"]
        XCTAssertNil(callbackType)
    }
    
    func testClearAllCallbacks() async {
        let registry = CallbackRegistry()
        await registry.register(type: "key1", callback: CustomCallback.self)
        await registry.register(type: "key2", callback: CustomCallback.self)
        await registry.reset()
        let count = await registry.callbacks.count
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
        await registry.register(type: "type1", callback: CustomCallback.self)
        await registry.register(type: "type2", callback: AnotherCallback.self)
        let type1 = await registry.callbacks["type1"]
        let type2 = await registry.callbacks["type2"]
        XCTAssertNotNil(type1)
        XCTAssertNotNil(type2)
        XCTAssertTrue(type1 is CustomCallback.Type)
        XCTAssertTrue(type2 is AnotherCallback.Type)
    }

    @MainActor
    func testConcurrentRegistration() async {
        let registry = CallbackRegistry()
        let iterations = 1000

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    await registry.register(type: "callback_\(i)", callback: CustomCallback.self)
                }
            }
        }

        let count = await registry.callbacks.count
        XCTAssertEqual(count, iterations)

        let keys = await registry.callbacks.keys
        let actualKeys = Set(keys)

        let expectedKeys = Set((0..<iterations).map { "callback_\($0)" })
        XCTAssertEqual(actualKeys, expectedKeys)
    }


    @MainActor
    func testConcurrentReadWrite() async {
        let registry = CallbackRegistry()
        let iterations = 500

        async let writer: Void = {
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<iterations {
                    group.addTask {
                        await registry.register(type: "callback_\(i)", callback: CustomCallback.self)
                    }
                }
            }
        }()

        let reader = Task { () -> [Int] in
            await withTaskGroup(of: Int.self) { group in
                for _ in 0..<iterations {
                    group.addTask { await registry.callbacks.count }
                }
                var results: [Int] = []
                results.reserveCapacity(iterations)
                for await c in group { results.append(c) }
                return results
            }
        }

        _ = await writer
        let readResults = await reader.value

        let finalCount = await registry.callbacks.count
        XCTAssertEqual(finalCount, iterations)
        XCTAssertFalse(readResults.isEmpty)
    }

}
