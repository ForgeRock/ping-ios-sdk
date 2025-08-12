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

class SuspendedTextCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "SuspendedTextCallbackTest"
    
    func testChoiceCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        XCTAssertEqual(1, nextNode.callbacks.count)
        guard let suspendedTextOutputCallback = nextNode.callbacks.first as? SuspendedTextOutputCallback else {
            XCTFail("Expected SuspendedTextOutputCallback")
            return
        }

        // Assert the callback properties
        XCTAssertTrue(suspendedTextOutputCallback.message.contains("An email has been sent to the address you entered"))
    }
}
