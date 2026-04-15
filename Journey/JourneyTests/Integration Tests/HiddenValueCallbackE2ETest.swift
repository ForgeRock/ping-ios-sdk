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

class HiddenValueCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "HiddenValueCallbackTest"
    
    func testHiddenValueCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Access the first callback and ensure it's a HiddenValueCallback
        guard let hiddenValueCallback = nextNode.callbacks.first as? HiddenValueCallback else {
            XCTFail("Expected HiddenValueCallback")
            return
        }

        XCTAssertEqual("myId", hiddenValueCallback.valueId)
        XCTAssertEqual("myValue", hiddenValueCallback.value)

        hiddenValueCallback.value = "test"

        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting the hidden value callback")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
