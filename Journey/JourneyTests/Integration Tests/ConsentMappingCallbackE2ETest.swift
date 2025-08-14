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

class ConsentMappingCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "ConsentMappingCallbackTest"
    
    func testConsentMappingCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        // Access the first callback and ensure it's a ConsentMappingCallback
        guard let consentMappingCallback = nextNode.callbacks.first as? ConsentMappingCallback else {
            XCTFail("Expected ConsentMappingCallback")
            return
        }

        XCTAssertEqual("Actual Profile", consentMappingCallback.accessLevel)
        XCTAssertEqual("Identity Mapping", consentMappingCallback.displayName)
        XCTAssertNotNil(consentMappingCallback.icon)
        XCTAssertTrue(consentMappingCallback.isRequired)
        XCTAssertEqual("Test", consentMappingCallback.message)
        XCTAssertEqual("managedUser_managedUser", consentMappingCallback.name)

        consentMappingCallback.accepted = true

        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting consent choice")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
