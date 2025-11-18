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

class TextOutputCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "TextOutputCallbackTest"
    
    func testTextOutputCallback() async throws {
        // Start the journey and cast to ContinueNode
        guard let node = await defaultJourney.start(testTree) as? ContinueNode else {
            XCTFail("Expected ContinueNode at start")
            return
        }
        
        // Handle name callback
        guard let usernameCallback = node.callbacks.first as? NameCallback else {
            XCTFail("Missing expected Name callback")
            return
        }
        usernameCallback.name = username
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        guard let passwordCallback = node.callbacks.first as? PasswordCallback else {
            XCTFail("Missing expected password callback")
            return
        }
        passwordCallback.password = password
        
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Access the first callback and ensure it's a TextOutputCallback of information type
        guard let callback = node.callbacks[0] as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual("TextOutput Type 0 (INFO)", callback.message)
        XCTAssertEqual(MessageType.information, callback.messageType)

        // Access the second callback and ensure it's a TextOutputCallback of warning type
        guard let callback = node.callbacks[1] as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual("TextOutput Type 1 (WARNING)", callback.message)
        XCTAssertEqual(MessageType.warning, callback.messageType)
        
        // Access the third callback and ensure it's a TextOutputCallback of error type
        guard let callback = node.callbacks[2] as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual("TextOutput Type 2 (ERROR)", callback.message)
        XCTAssertEqual(MessageType.error, callback.messageType)
        
        // Access the fourth callback and ensure it's a TextOutputCallback of script type
        guard let callback = node.callbacks[3] as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual("TextOutput Type 4 (SCRIPT)", callback.message)
        // ToDo: Align the "Type 4" value later... see SDKS-4194
        XCTAssertEqual(MessageType.script, callback.messageType)

        // Submit callback and expect SuccessNode
        guard let result = await node.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting choice")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
