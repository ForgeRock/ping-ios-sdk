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

class NumberAttributeInputCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "NumberAttributeInputCallbackTest"
    
    func testNumberAttributeInputCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        
        guard let numberAttributeInputCallback = nextNode.callbacks.first as? NumberAttributeInputCallback else {
            XCTFail("Expected NumberAttributeInputCallback")
            return
        }
        XCTAssertTrue(numberAttributeInputCallback.name.contains("age"))
        XCTAssertEqual("How old are you?", numberAttributeInputCallback.prompt)
        XCTAssertEqual(true, numberAttributeInputCallback.required)
        XCTAssertTrue(numberAttributeInputCallback.policies.isEmpty)
        XCTAssertTrue(numberAttributeInputCallback.failedPolicies.isEmpty)
        // Set the value to 30.0 and continue
        numberAttributeInputCallback.value = 30.0
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting the number attribute input callback")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
