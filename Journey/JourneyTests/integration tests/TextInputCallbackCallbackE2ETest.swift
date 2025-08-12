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

class TextInputCallbackCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "TextInputCallbackTest"
    
    func testTextInputCallback() async throws {
        // Start the journey and cast to ContinueNode
        guard let node = await defaultJourney.start(testTree) as? ContinueNode else {
            XCTFail("Expected ContinueNode at start")
            return
        }
        
        // Handle login callbacks
        guard let usernameCallback = node.callbacks.first as? NameCallback else {
            XCTFail("Missing expected Name callbacks")
            throw XCTSkip("Callbacks missing")
        }
        usernameCallback.name = username
        
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Access the first callback and ensure it's a TextInputCallback
        guard let textInputCallback = nextNode.callbacks.first as? TextInputCallback else {
            XCTFail("Expected TextInputCallback")
            return
        }

        // Assert choice callback properties
        XCTAssertEqual(textInputCallback.prompt, "What is your username?")
        XCTAssertEqual(textInputCallback.defaultText, "ForgerRocker")

        textInputCallback.text = username
        
        // This step here is to ensure that the SDK correctly sets the value in the TextInputCallback...
        // The values entered in the NameCallback and TextInputCallback above should match for "success"
        guard let nextNode = await nextNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }

        // Access the first callback and ensure it's a TextOutputCallback
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback...")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Success")
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting choice")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
