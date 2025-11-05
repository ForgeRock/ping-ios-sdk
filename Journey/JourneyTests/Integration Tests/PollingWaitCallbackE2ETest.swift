/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingOidc
@testable import PingLogger

class PollingWaitCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "PollingWaitCallbackTest"
    
    func testPollingWaitCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        guard let pollingWaitCallback = nextNode.callbacks.first as? PollingWaitCallback,
              let confirmationCallback = nextNode.callbacks.last as? ConfirmationCallback else {
            XCTFail("Missing expected PollingWaitCallback and ConfirmationCallback callbacks")
            return
        }
        
        XCTAssertEqual(5000, pollingWaitCallback.waitTime)
        XCTAssertEqual("Please Wait", pollingWaitCallback.message)
        
        XCTAssertTrue(confirmationCallback.options.contains("Exit"))
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode since the polling wait has not expired yet.")
            return
        }
        
        XCTAssertTrue(result.callbacks.first is PollingWaitCallback)
        XCTAssertTrue(result.callbacks.last is ConfirmationCallback)
        
        // Simulate the polling wait timeout
        try await Task.sleep(nanoseconds: 6_000_000_000) // 6 seconds
        
        // Proceed to next node
        guard let errorNode = await result.next() as? ErrorNode else {
            XCTFail("Expected ErrorNode")
            return
        }

        // Assert the error message
        XCTAssertEqual(errorNode.message, "Login failure")
    }
}
