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
        let expectation = self.expectation(description: "Concurrent registration completes")
        let iterations = 1000 // Increase iterations to make race conditions more likely
        let group = DispatchGroup()

        // Use multiple concurrent queues to increase contention
        for queueIndex in 0..<10 {
            let queue = DispatchQueue(label: "test.queue.\(queueIndex)", qos: .userInitiated)
            group.enter()

            queue.async { [registry] in
                DispatchQueue.concurrentPerform(iterations: iterations / 10) { index in
                    let key = "callback_\(queueIndex)_\(index)"
                    Task {
                        await registry.register(type: key, callback: CustomCallback.self)
                    }
                }
                group.leave()
            }
        }

        group.notify(queue: .main) { [expectation] in
            expectation.fulfill()
        }

        // Async XCTest API
        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify count and uniqueness
        let count = await registry.callbacks.count
        XCTAssertEqual(count, iterations)

        // Verify all keys are present and unique
        let expectedKeys = Set((0..<10).flatMap { queueIndex in
            (0..<(iterations/10)).map { index in "callback_\(queueIndex)_\(index)" }
        })
        let actualKeys = Set(await registry.callbacks.keys)
        XCTAssertEqual(actualKeys, expectedKeys)
    }

    @MainActor
    func testConcurrentReadWrite() async {
        let registry = CallbackRegistry()
        let expectation = self.expectation(description: "Concurrent read/write completes")
        let iterations = 500
        var readResults: [Int] = []
        let resultsQueue = DispatchQueue(label: "results.queue")

        let group = DispatchGroup()

        // Writer: use Swift concurrency to hop onto the actor
        group.enter()
        Task.detached { [registry] in
            await withTaskGroup(of: Void.self) { taskGroup in
                for index in 0..<iterations {
                    taskGroup.addTask {
                        await registry.register(type: "callback_\(index)", callback: CustomCallback.self)
                    }
                }
                // Implicitly awaits all child tasks when taskGroup goes out of scope
            }
            group.leave()
        }

        // Reader queue
        group.enter()
        DispatchQueue.global().async { [registry, resultsQueue] in
            DispatchQueue.concurrentPerform(iterations: iterations) { _ in
                // Take a snapshot by hopping to the actor to read count
                Task {
                    let count = await registry.callbacks.count
                    resultsQueue.async {
                        readResults.append(count)
                    }
                }
            }
            group.leave()
        }

        group.notify(queue: .main) { [expectation] in
            expectation.fulfill()
        }

        // Async XCTest API
        await fulfillment(of: [expectation], timeout: 10.0)

        // Verify final state
        let finalCount = await registry.callbacks.count
        XCTAssertEqual(finalCount, iterations)
        XCTAssertFalse(readResults.isEmpty)
    }

}
