// 
//  ReCaptchaEnterpriseCallbackE2ETests.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingJourney
@testable import PingOrchestrate
@testable import PingLogger
@testable import PingReCaptchaEnterprise
@testable import PingJourneyPlugin

class ReCaptchaEnterpriseCallbackE2ETests: BindingE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    var testTree = "TEST-e2e-recaptcha-enterprise"
    
    static let SITE_KEY: String = "6Lc0NUIqAAAAALRSrhXb5CWrZPzWkezBFB_0mnqS" // this is configured in the test journey
    
    func testRecaptchaEnterpriseSuccess() async throws {
        // Navigate to the ReCaptchaEnterprise node
        let node = try await startTest(nodeConfiguration: "success")
        
        // We expect ReCaptchaEnterpriseCallback here
        guard let reCaptchaEnterpriseCallback = node.callbacks.first as? ReCaptchaEnterpriseCallback else {
            XCTFail("Expected ReCaptchaEnterpriseCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertEqual(reCaptchaEnterpriseCallback.recaptchaSiteKey, ReCaptchaEnterpriseCallbackE2ETests.SITE_KEY)
        
        // Execute reCAPTCHA verification
        let verifyResult = await reCaptchaEnterpriseCallback.verify()
        
        var tokenResult = ""
        switch verifyResult {
        case .success(let token):
            XCTAssertFalse(token.isEmpty, "Token should not be empty")
            tokenResult = token
        case .failure(let error):
            XCTFail("reCaptchaEnterpriseCallback.verify() failed: \(error)")
            return
        }
        
        // Submit ReCaptchaEnterpriseCallback and continue
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting ReCaptchaEnterpriseCallback")
            return
        }
        
        // Confirm that reCAPTCHA Enterprise node execution is successful.
        // Note: Upon success the test tree returns CaptchaEnterpriseNode.ASSESSMENT_RESULT in a TextOutput callback...
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with assessment result")
            return
        }
        
        let assessmentData = Data(textOutputCallback.message.utf8)
        
        do {
            if let assessmentDictionary = try JSONSerialization.jsonObject(with: assessmentData, options: []) as? [String: Any] {
                // Assert a few things in the assessment data:
                let event = assessmentDictionary["event"] as! [String: Any]
                let tokenProperties = assessmentDictionary["tokenProperties"] as! [String: Any]
                let riskAnalysis = assessmentDictionary["riskAnalysis"] as! [String: Any]
                
                let userAgent = event["userAgent"] as! String
                let siteKey = event["siteKey"] as! String
                let userIpAddress = event["userIpAddress"] as! String
                let token = event["token"] as! String
                let action = tokenProperties["action"] as! String
                let valid = tokenProperties["valid"] as! Bool
                let iosBundleId = tokenProperties["iosBundleId"] as! String
                let score = riskAnalysis["score"] as! Double
                
                XCTAssertEqual(siteKey, ReCaptchaEnterpriseCallbackE2ETests.SITE_KEY)
                XCTAssert(userAgent.contains("Darwin"))
                XCTAssert(!userIpAddress.isEmpty)
                XCTAssertEqual(token, tokenResult)
                XCTAssertEqual(action, "login")
                XCTAssertTrue(valid)
                XCTAssertEqual(iosBundleId, "com.pingidentity.PingTestHost")
                XCTAssertGreaterThanOrEqual(score, 0.0)
                XCTAssertLessThanOrEqual(score, 1.0)
            }
        } catch {
            XCTFail("Error parsing the assessment data \(error)")
        }
        
        // Submit the TextOutput callback and complete the flow
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting TextOutput callback")
            return
        }
        
        // At the end the user should be logged in
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testRecaptchaEnterpriseSuccessCustom() async throws {
        // Navigate to the ReCaptchaEnterprise node
        let node = try await startTest(nodeConfiguration: "success")
        
        // We expect ReCaptchaEnterpriseCallback here
        guard let reCaptchaEnterpriseCallback = node.callbacks.first as? ReCaptchaEnterpriseCallback else {
            XCTFail("Expected ReCaptchaEnterpriseCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Execute reCAPTCHA verification with custom payload and action
        let verifyResult = await reCaptchaEnterpriseCallback.verify { config in
            config.action = "custom_action"
            config.payload = ["firewallPolicyEvaluation": false,
                              "express": false,
                              "transaction_data": [
                                "transaction_id": "custom-payload-1234567890",
                                "payment_method": "credit-card",
                                "card_bin": "1111",
                                "card_last_four": "1234",
                                "currency_code": "CAD"
                              ]]
        }
        
        switch verifyResult {
        case .success:
            break // Expected
        case .failure(let error):
            XCTFail("reCaptchaEnterpriseCallback.verify() failed: \(error)")
            return
        }
        
        // Submit ReCaptchaEnterpriseCallback and continue
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting ReCaptchaEnterpriseCallback")
            return
        }
        
        // Confirm that reCAPTCHA Enterprise node execution is successful.
        // Note: Upon success the test tree returns CaptchaEnterpriseNode.ASSESSMENT_RESULT in a TextOutput callback...
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with assessment result")
            return
        }
        
        let assessmentData = Data(textOutputCallback.message.utf8)
        
        do {
            if let assessmentDictionary = try JSONSerialization.jsonObject(with: assessmentData, options: []) as? [String: Any] {
                // Assert that the custom payload and action has been taken into account...
                let event = assessmentDictionary["event"] as! [String: Any]
                let tokenProperties = assessmentDictionary["tokenProperties"] as! [String: Any]
                let transactionData = event["transactionData"] as! [String: Any]
                
                let firewallPolicyEvaluation = event["firewallPolicyEvaluation"] as! Bool
                let express = event["express"] as! Bool
                let action = tokenProperties["action"] as! String
                let valid = tokenProperties["valid"] as! Bool
                
                let transactionId = transactionData["transactionId"] as! String
                let paymentMethod = transactionData["paymentMethod"] as! String
                let cardBin = transactionData["cardBin"] as! String
                let cardLastFour = transactionData["cardLastFour"] as! String
                let currencyCode = transactionData["currencyCode"] as! String
                
                XCTAssertFalse(firewallPolicyEvaluation) // This is to prove that custom payload has been applied
                XCTAssertFalse(express)
                XCTAssertEqual(action, "custom_action")
                XCTAssertTrue(valid)
                
                // These come from the custom payload:
                XCTAssertEqual(transactionId, "custom-payload-1234567890")
                XCTAssertEqual(paymentMethod, "credit-card")
                XCTAssertEqual(cardBin, "1111")
                XCTAssertEqual(cardLastFour, "1234")
                XCTAssertEqual(currencyCode, "CAD")
            }
        } catch {
            XCTFail("Error parsing the assessment data \(error)")
        }
        
        // Submit the TextOutput callback and complete the flow
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting TextOutput callback")
            return
        }
        
        // At the end the user should be logged in
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testRecaptchaEnterpriseFailScore() async throws {
        // Navigate to the ReCaptchaEnterprise node with score_failure configuration
        let node = try await startTest(nodeConfiguration: "score_failure")
        
        // We expect ReCaptchaEnterpriseCallback here
        guard let reCaptchaEnterpriseCallback = node.callbacks.first as? ReCaptchaEnterpriseCallback else {
            XCTFail("Expected ReCaptchaEnterpriseCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        XCTAssertNotNil(reCaptchaEnterpriseCallback.recaptchaSiteKey)
        
        // Execute reCAPTCHA verification
        let verifyResult = await reCaptchaEnterpriseCallback.verify()
        
        switch verifyResult {
        case .success:
            break // Token acquisition succeeds, but score validation should fail server-side
        case .failure(let error):
            XCTFail("reCaptchaEnterpriseCallback.verify() failed: \(error)")
            return
        }
        
        // Submit ReCaptchaEnterpriseCallback and continue
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting ReCaptchaEnterpriseCallback")
            return
        }
        
        // Confirm that reCAPTCHA Enterprise node execution fails (since the "Score threshold" is set to 1.0)
        // Note: Upon failure the test tree returns CaptchaEnterpriseNode.FAILURE in a TextOutput callback...
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with failure message")
            return
        }
        XCTAssertTrue(textOutputCallback.message.contains("VALIDATION_ERROR:CAPTCHA validation failed"))
        
        // Submit the TextOutput callback and complete the flow
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting TextOutput callback")
            return
        }
        
        // At the end the user should be logged in
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    func testRecaptchaEnterpriseCustomClientError() async throws {
        // Navigate to the ReCaptchaEnterprise node with custom_client_error configuration
        let node = try await startTest(nodeConfiguration: "custom_client_error")
        
        // We expect ReCaptchaEnterpriseCallback here
        guard let reCaptchaEnterpriseCallback = node.callbacks.first as? ReCaptchaEnterpriseCallback else {
            XCTFail("Expected ReCaptchaEnterpriseCallback but got \(node.callbacks.map { type(of: $0) })")
            return
        }
        
        // Set a custom client error before executing
        reCaptchaEnterpriseCallback.setClientError("CUSTOM_CLIENT_ERROR")
        
        // Execute reCAPTCHA verification
        let verifyResult = await reCaptchaEnterpriseCallback.verify()
        
        switch verifyResult {
        case .success:
            break // Token acquisition may still succeed
        case .failure:
            break // Or it may fail - either way, the client error should be reported
        }
        
        // Submit ReCaptchaEnterpriseCallback and continue
        guard let nextNode = await node.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after submitting ReCaptchaEnterpriseCallback")
            return
        }
        
        // Confirm that reCAPTCHA Enterprise node execution fails (since we have set client error)
        // Note: Upon failure the test tree returns CaptchaEnterpriseNode.FAILURE in a TextOutput callback...
        guard let textOutputCallback = nextNode.callbacks.first as? TextOutputCallback else {
            XCTFail("Expected TextOutputCallback with failure message")
            return
        }
        XCTAssertTrue(textOutputCallback.message.contains("CLIENT_ERROR:CUSTOM_CLIENT_ERROR"))
        
        // Submit the TextOutput callback and complete the flow
        guard let result = await nextNode.next() as? SuccessNode else {
            XCTFail("Expected SuccessNode after submitting TextOutput callback")
            return
        }
        
        // At the end the user should be logged in
        XCTAssertNotNil(result.session)
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
    }
    
    // MARK: - Helper Methods
    
    /// Common steps for all test cases:
    /// 1. Start journey and provide username via NameCallback
    /// 2. Select nodeConfiguration via ChoiceCallback
    /// 3. Return the resulting ContinueNode (typically the ReCaptchaEnterprise node)
    private func startTest(nodeConfiguration: String) async throws -> ContinueNode {
        // Start the journey
        let node = await defaultJourney.start(testTree)
        
        // First node: Username collector
        guard let usernameNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode (Username collector) but got \(type(of: node))")
            throw XCTSkip("Failed to get username collector node")
        }
        
        guard let nameCallback = usernameNode.callbacks.first as? NameCallback else {
            XCTFail("Expected NameCallback for username collection")
            throw XCTSkip("Missing NameCallback")
        }
        nameCallback.name = username
        
        // Second node: Choice collector
        guard let choiceNode = await usernameNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode (Choice collector) after username")
            throw XCTSkip("Failed to get choice collector node")
        }
        
        guard let choiceCallback = choiceNode.callbacks.first as? ChoiceCallback else {
            XCTFail("Expected ChoiceCallback for node configuration selection")
            throw XCTSkip("Missing ChoiceCallback")
        }
        
        // Select the requested node configuration
        if let choiceIndex = choiceCallback.choices.firstIndex(of: nodeConfiguration) {
            choiceCallback.selectedIndex = choiceIndex
        } else {
            XCTFail("Choice '\(nodeConfiguration)' not found in available choices: \(choiceCallback.choices)")
            throw XCTSkip("Invalid choice configuration")
        }
        
        // Third node: ReCaptchaEnterprise callback (or result node)
        guard let resultNode = await choiceNode.next() as? ContinueNode else {
            XCTFail("Expected ContinueNode after selecting '\(nodeConfiguration)'")
            throw XCTSkip("Failed to get result node")
        }
        
        return resultNode
    }
}
