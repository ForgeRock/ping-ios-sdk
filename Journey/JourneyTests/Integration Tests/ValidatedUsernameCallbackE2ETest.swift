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

class ValidatedUsernameCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "ValidatedUsernameCallbackTest"
    
    func testValidatedUsernameCallback() async throws {
        // Start the journey and cast to ContinueNode
        guard let node = await defaultJourney.start(testTree) as? ContinueNode else {
            XCTFail("Expected ContinueNode at start")
            return
        }

        XCTAssertEqual(1, node.callbacks.count)
        // Handle ValidatedUsernameCallback callback
        guard let validatedUsernameCallback = node.callbacks.first as? ValidatedUsernameCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        XCTAssertEqual("Username", validatedUsernameCallback.prompt)
        XCTAssertFalse(validatedUsernameCallback.policies.isEmpty)
        XCTAssertTrue(validatedUsernameCallback.policies.keys.contains("policyRequirements"))
        XCTAssertTrue(validatedUsernameCallback.policies.keys.contains("fallbackPolicies"))
        XCTAssertTrue(validatedUsernameCallback.policies.keys.contains("name"))
        XCTAssertTrue(validatedUsernameCallback.policies.keys.contains("policies"))
        XCTAssertTrue(validatedUsernameCallback.policies.keys.contains("conditionalPolicies"))
        XCTAssertEqual(0, validatedUsernameCallback.failedPolicies.count)
        
        // Try to enter username of already existing user.
        // This should cause the validation policy to fail...
        validatedUsernameCallback.username = username
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        // We expect the same callback (ValidatedUsernameCallback) to be returned
        XCTAssertEqual(1, node.callbacks.count)
        guard let validatedUsernameCallback = node.callbacks.first as? ValidatedUsernameCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        
        XCTAssertEqual(1, validatedUsernameCallback.failedPolicies.count)
        XCTAssertTrue(validatedUsernameCallback.failedPolicies.contains { $0.policyRequirement == "VALID_USERNAME" })
        XCTAssertFalse(validatedUsernameCallback.failedPolicies.contains { $0.policyRequirement == "CANNOT_CONTAIN_CHARACTERS" })
        
        // Now try to enter a username with invalid character "/". This should also fail...
        validatedUsernameCallback.username = "invalid/characters"
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        // We expect the same callback (ValidatedUsernameCallback) to be returned
        XCTAssertEqual(1, node.callbacks.count)
        guard let validatedUsernameCallback = node.callbacks.first as? ValidatedUsernameCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        
        XCTAssertEqual(1, validatedUsernameCallback.failedPolicies.count)
        XCTAssertFalse(validatedUsernameCallback.failedPolicies.contains { $0.policyRequirement == "VALID_USERNAME" })
        XCTAssertTrue(validatedUsernameCallback.failedPolicies.contains { $0.policyRequirement == "CANNOT_CONTAIN_CHARACTERS" })
        
        // Finally, enter a valid username
        validatedUsernameCallback.username = "username" + String(Int(Date().timeIntervalSince1970 * 1000))
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        
        // Handle login callbacks
        XCTAssertEqual(2, node.callbacks.count)
        guard let usernameCallback = node.callbacks.first as? NameCallback,
              let passwordCallback = node.callbacks.last as? PasswordCallback else {
            XCTFail("Missing expected Name and Password callbacks")
            return
        }
        
        usernameCallback.name = username
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
