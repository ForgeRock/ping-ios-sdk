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

class ConfirmationCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "ConfirmationCallbackTest"
    
    func testConfirmationCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Handle TextOutputCallback
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback")
            return
        }
        XCTAssertEqual(textOutputCallback.message, "Test")
        XCTAssertEqual(textOutputCallback.messageType, MessageType.information)

        // Handle ConfirmationCallback
        guard let confirmationCallback = nextNode.callbacks.last as? ConfirmationCallback else {
            XCTFail("Expected ConfirmationCallback")
            return
        }

        XCTAssertEqual(confirmationCallback.prompt, "")
        XCTAssertEqual(confirmationCallback.defaultOption, 1)
        XCTAssertEqual(confirmationCallback.messageType, MessageType.information)
        XCTAssertEqual(confirmationCallback.optionType, OptionType.unspecified)
        XCTAssertEqual(confirmationCallback.options.count, 2)
        XCTAssertTrue(confirmationCallback.options.contains("Yes"))
        XCTAssertTrue(confirmationCallback.options.contains("No"))

        // Select "Yes"
        confirmationCallback.selectedIndex = 0

        // Submit and check for success
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after confirmation")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
