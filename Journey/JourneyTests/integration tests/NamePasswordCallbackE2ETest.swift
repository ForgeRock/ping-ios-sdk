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

class NamePasswordCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "NamePasswordCallbackTest"
    
    func testNamePasswordCallbacks() async throws {
        // Start the journey and cast to ContinueNode
        guard var node = await defaultJourney.start(testTree) as? ContinueNode else {
            XCTFail("Expected ContinueNode at start")
            return
        }

        XCTAssertEqual(1, node.callbacks.count)
        guard let nameCallback = node.callbacks.first as? NameCallback else {
            XCTFail("Missing expected Name callback")
            return
        }
        
        XCTAssertEqual("User Name", nameCallback.prompt)
        nameCallback.name = username
        node = await node.next() as! ContinueNode

        XCTAssertEqual(1, node.callbacks.count)
        guard let passwordCallback = node.callbacks.first as? PasswordCallback else {
            XCTFail("Missing expected Name callback")
            return
        }
        XCTAssertEqual("Password", passwordCallback.prompt)
        passwordCallback.password = password
        
        // Submit callback and expect SuccessNode
        guard let result = await node.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting username and password callbacks")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
