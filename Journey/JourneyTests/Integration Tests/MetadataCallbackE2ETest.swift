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

class MetadataCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "MetadataCallbackTest"
    
    func testMetadataCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        XCTAssertEqual(2, nextNode.callbacks.count)
        
        guard let metadataCallback = nextNode.callbacks.first as? MetadataCallback else {
            XCTFail("Expected MetadataCallback")
            return
        }
        guard let choiceCallback = nextNode.callbacks.last as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback")
            return
        }
        
        // Assert that the metadata callback contains the expected keys and values
        XCTAssertEqual(2, metadataCallback.value.count)
        XCTAssertTrue(metadataCallback.value.keys.contains("username"))
        XCTAssertTrue(metadataCallback.value.keys.contains("custom"))

        XCTAssertEqual(username, metadataCallback.value["username"] as? String)
        XCTAssertEqual("dummy value", metadataCallback.value["custom"] as? String)

        // Select "Yes" in the ChoiceCallback and finish the journey
        XCTAssertTrue(choiceCallback.choices.contains("Yes"))
        XCTAssertTrue(choiceCallback.choices.contains("No"))
        choiceCallback.selectedIndex = 0
        
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
