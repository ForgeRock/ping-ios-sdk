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

class StringAttributeInputCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "StringAttributeInputCallbackTest"
    
    func testStringAttributeInputCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }

        XCTAssertEqual(3, nextNode.callbacks.count)
        guard let mail = nextNode.callbacks[0] as? StringAttributeInputCallback else {
            XCTFail("Expected StringAttributeInputCallback")
            return
        }
        guard let givenName = nextNode.callbacks[1] as? StringAttributeInputCallback else {
            XCTFail("Expected StringAttributeInputCallback")
            return
        }
        guard let sn = nextNode.callbacks[2] as? StringAttributeInputCallback else {
            XCTFail("Expected StringAttributeInputCallback")
            return
        }
        
        XCTAssertEqual("mail", mail.name)
        XCTAssertEqual("Email Address", mail.prompt)
        XCTAssertTrue(mail.required)
        XCTAssertTrue(mail.policies.isEmpty)
        XCTAssertTrue(mail.failedPolicies.isEmpty)
        XCTAssertFalse(mail.validateOnly)
        mail.value = "test@mail.com"

        XCTAssertEqual("givenName", givenName.name)
        XCTAssertEqual("First Name", givenName.prompt)
        XCTAssertTrue(givenName.required)
        XCTAssertTrue(givenName.policies.isEmpty)
        XCTAssertTrue(givenName.failedPolicies.isEmpty)
        XCTAssertFalse(givenName.validateOnly)
        givenName.value = "Given"

        XCTAssertEqual("sn", sn.name)
        XCTAssertEqual("Last Name", sn.prompt)
        XCTAssertTrue(sn.required)
        XCTAssertTrue(sn.policies.isEmpty)
        XCTAssertTrue(sn.failedPolicies.isEmpty)
        XCTAssertFalse(sn.validateOnly)
        sn.value = "Lastname"

        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting the StringAttributeInput callbacks")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
