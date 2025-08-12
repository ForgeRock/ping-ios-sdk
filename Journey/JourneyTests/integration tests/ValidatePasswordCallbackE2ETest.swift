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

class ValidatePasswordCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "ValidatedPasswordCallbackTest"
    
    func testValidatedPasswordCallback() async throws {
        // Start the journey and cast to ContinueNode
        guard let node = await defaultJourney.start(testTree) as? ContinueNode else {
            XCTFail("Expected ContinueNode at start")
            return
        }

        XCTAssertEqual(1, node.callbacks.count)
        // Handle ValidatedPasswordCallback callback
        guard let validatedPasswordCallback = node.callbacks.first as? ValidatedPasswordCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        XCTAssertEqual("Password", validatedPasswordCallback.prompt)
        XCTAssertFalse(validatedPasswordCallback.policies.isEmpty)
        XCTAssertTrue(validatedPasswordCallback.policies.keys.contains("policyRequirements"))
        XCTAssertTrue(validatedPasswordCallback.policies.keys.contains("fallbackPolicies"))
        XCTAssertTrue(validatedPasswordCallback.policies.keys.contains("name"))
        XCTAssertTrue(validatedPasswordCallback.policies.keys.contains("policies"))
        XCTAssertTrue(validatedPasswordCallback.policies.keys.contains("conditionalPolicies"))
        XCTAssertEqual(0, validatedPasswordCallback.failedPolicies.count)
        
        // Try to enter an empty password. This should cause the validation policy to fail...
        validatedPasswordCallback.password = ""
        
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        
        // We expect the same callback (ValidatedPasswordCallback) to be returned
        XCTAssertEqual(1, node.callbacks.count)
        guard let validatedPasswordCallback = node.callbacks.first as? ValidatedPasswordCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        
        XCTAssertEqual(1, validatedPasswordCallback.failedPolicies.count)
        XCTAssertTrue(validatedPasswordCallback.failedPolicies.contains { $0.policyRequirement == "LENGTH_BASED" })
        
        // Now try with short password. This should also fail...
        validatedPasswordCallback.password = "123"
        
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        
        // We expect the same callback (ValidatedPasswordCallback) to be returned
        XCTAssertEqual(1, node.callbacks.count)
        guard let validatedPasswordCallback = node.callbacks.first as? ValidatedPasswordCallback else {
            XCTFail("Missing expected ValidatedUsernameCallback callback")
            return
        }
        
        XCTAssertEqual(1, validatedPasswordCallback.failedPolicies.count)
        XCTAssertTrue(validatedPasswordCallback.failedPolicies.contains { $0.policyRequirement == "LENGTH_BASED" })
        
        // Finally, enter a valid password.
        validatedPasswordCallback.password = "ForgeR0cks1234!"
        guard let node = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode...")
            return
        }
        XCTAssertEqual(2, node.callbacks.count)
        
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
