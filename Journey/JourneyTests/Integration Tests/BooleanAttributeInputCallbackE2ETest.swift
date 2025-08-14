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

class BooleanAttributeInputCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "BooleanAttributeInputCallbackTest"
    
    func testBooleanAttributeInputCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        guard let callback = nextNode.callbacks.first as? BooleanAttributeInputCallback else {
            XCTFail("Expected BooleanAttributeInputCallback")
            return
        }

        // Assertions for callback properties
        XCTAssertEqual(callback.name, "preferences/marketing")
        XCTAssertEqual(callback.prompt, "Send me special offers and services")
        XCTAssertEqual(callback.required, true)
        XCTAssertEqual(callback.policies.count, 0)
        XCTAssertTrue(callback.failedPolicies.isEmpty)
        XCTAssertEqual(callback.validateOnly, false)
        XCTAssertEqual(callback.value, false)

        // Set value to true and continue
        callback.value = true

        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting BooleanAttributeInputCallback")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
