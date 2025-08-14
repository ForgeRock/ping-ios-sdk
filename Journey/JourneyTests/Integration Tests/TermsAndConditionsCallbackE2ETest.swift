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

class TermsAndConditionsCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "TermsAndConditionCallbackTest"
    
    func testTermsAndConditionsCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        guard let callback = nextNode.callbacks.first as? TermsAndConditionsCallback else {
            XCTFail("Expected TermsAndConditionsCallback")
            return
        }

        // Assertions for callback properties
        XCTAssertNotNil(callback.terms)
        XCTAssertNotNil(callback.version)
        XCTAssertNotNil(callback.createDate)
        callback.accepted = true

        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting TermsAndConditionsCallback")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
