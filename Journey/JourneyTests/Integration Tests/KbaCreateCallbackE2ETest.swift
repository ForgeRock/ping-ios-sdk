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

class KbaCreateCallbackE2ETest: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "KbaCreateCallbackTest"
    
    func testKbaCreateCallback() async throws {
        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(treeName: testTree)
        guard let nextNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode after first step")
            return
        }
        XCTAssertEqual(2, nextNode.callbacks.count)
        
        guard let firstQuestion = nextNode.callbacks.first as? KbaCreateCallback else {
            XCTFail("Expected KbaCreateCallback")
            return
        }
        guard let secondQuestion = nextNode.callbacks.last as? KbaCreateCallback else {
            XCTFail("Expected KbaCreateCallback")
            return
        }
        
        XCTAssertEqual(2, firstQuestion.predefinedQuestions.count)
        firstQuestion.selectedQuestion = firstQuestion.predefinedQuestions[0]
        firstQuestion.selectedAnswer = "Yellow"
        XCTAssertTrue(firstQuestion.allowUserDefinedQuestions)
        XCTAssertEqual("Security questions", firstQuestion.prompt)

        XCTAssertEqual(2, secondQuestion.predefinedQuestions.count)
        secondQuestion.selectedQuestion = "What city were you born in?"
        secondQuestion.selectedAnswer = "Plovdiv"
        XCTAssertTrue(secondQuestion.allowUserDefinedQuestions)
        XCTAssertEqual("Security questions", secondQuestion.prompt)
        
        // Submit callback and expect SuccessNode
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting the KBA callbacks")
            return
        }

        logger.i("Session: \(result.session.value)")

        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
}
