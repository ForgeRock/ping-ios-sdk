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

class ChoiceCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "ChoiceCallbackTest"
    
    func testChoiceCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Access the first callback and ensure it's a ChoiceCallback
        guard let choiceCallback = nextNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            return
        }

        // Assert choice callback properties
        XCTAssertEqual(choiceCallback.prompt, "Choice")
        XCTAssertEqual(choiceCallback.defaultChoice, 0)
        XCTAssertEqual(choiceCallback.choices.count, 2)
        XCTAssertTrue(choiceCallback.choices.contains("Yes"))
        XCTAssertTrue(choiceCallback.choices.contains("No"))

        // Select "Yes"
        choiceCallback.selectedIndex = 0

        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting the choice")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
