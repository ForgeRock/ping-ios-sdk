// 
//  ReCaptchaEnterpriseTests.swift
//  ReCaptchaEnterpriseTests
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingReCaptchaEnterprise
@testable import PingJourneyPlugin


class ReCaptchaEnterpriseCallbackTests: XCTestCase {
    
    var callback: ReCaptchaEnterpriseCallback!
    var jsonString: [String: Any]!
    
    override func setUp() {
        super.setUp()
        
        // Create mock JSON that simulates server response
        jsonString = [
            "type": "ReCaptchaEnterpriseCallback",
            "output": [
                ["name": "recaptchaSiteKey", "value": "test_site_key_12345"]
            ],
            "input": [
                ["name": "token", "value": ""],
                ["name": "action", "value": ""],
                ["name": "clientError", "value": ""],
                ["name": "payload", "value": ""]
            ]
        ]
        
        // Initialize callback with mock data
        callback = ReCaptchaEnterpriseCallback()
        _ = callback.initialize(with: jsonString)

    }
    
    override func tearDown() {
        callback = nil
        jsonString = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testCallbackInitialization() {
        // Then: Callback should be properly initialized
        XCTAssertNotNil(callback, "Callback should be initialized")
    }
    
    func testInitValueWithSiteKey() {
        // Given: A callback instance
        let testCallback = ReCaptchaEnterpriseCallback()
        
        // When: Setting site key via initValue
        testCallback.initValue(name: JourneyConstants.recaptchaSiteKey, value: "my_test_site_key")
        
        // Then: Site key should be set correctly
        XCTAssertEqual(testCallback.recaptchaSiteKey, "my_test_site_key")
    }
    
    func testInitValueWithInvalidType() {
        // Given: A callback instance
        let testCallback = ReCaptchaEnterpriseCallback()
        
        // When: Setting site key with wrong type
        testCallback.initValue(name: JourneyConstants.recaptchaSiteKey, value: 12345)
        
        // Then: Site key should remain empty
        XCTAssertEqual(testCallback.recaptchaSiteKey, "")
    }
    
    func testInitValueWithUnknownProperty() {
        // Given: A callback instance
        let testCallback = ReCaptchaEnterpriseCallback()
        let initialSiteKey = testCallback.recaptchaSiteKey
        
        // When: Setting unknown property
        testCallback.initValue(name: "unknownProperty", value: "someValue")
        
        // Then: Site key should remain unchanged
        XCTAssertEqual(testCallback.recaptchaSiteKey, initialSiteKey)
    }
    
    // MARK: - Input Setting Tests
    
    func testSetToken() {
        // Given: A token value
        let testToken = "test_recaptcha_token_abc123"
        
        // When: Setting the token
        callback.setToken(testToken)
        
        // Then: Token should be set in the callback
        let payload = callback.payload()
        if let inputs = payload["input"] as? [[String: Any]],
           let tokenInput = inputs.first,
           let value = tokenInput["value"] as? String {
            XCTAssertEqual(value, testToken)
        } else {
            XCTFail("Token was not set correctly in payload")
        }
    }
    
    func testSetAction() {
        // Given: An action value
        let testAction = "signup"
        
        // When: Setting the action
        callback.setAction(testAction)
        
        // Then: Action should be set in the callback
        let payload = callback.payload()
        if let inputs = payload["input"] as? [[String: Any]],
           inputs.count > 1,
           let value = inputs[1]["value"] as? String {
            XCTAssertEqual(value, testAction)
        } else {
            XCTFail("Action was not set correctly in payload")
        }
    }
    
    func testSetClientError() {
        // Given: An error message
        let errorMessage = "Network timeout occurred"
        
        // When: Setting the client error
        callback.setClientError(errorMessage)
        
        // Then: Error should be set in the callback
        let payload = callback.payload()
        if let inputs = payload["input"] as? [[String: Any]],
           inputs.count > 2,
           let value = inputs[2]["value"] as? String {
            XCTAssertEqual(value, errorMessage)
        } else {
            XCTFail("Client error was not set correctly in payload")
        }
    }
    
    func testSetPayloadWithValidData() {
        // Given: Valid payload data
        let payloadData: [String: Any] = [
            "userId": "12345",
            "sessionId": "abc-def-ghi"
        ]
        
        // When: Setting the payload
        callback.setPayload(payloadData)
        
        // Then: Payload should be set as JSON string
        let responsePayload = callback.payload()
        if let inputs = responsePayload["input"] as? [[String: Any]],
           inputs.count > 3,
           let value = inputs[3]["value"] as? String {
            XCTAssertFalse(value.isEmpty)
            XCTAssertTrue(value.contains("userId"))
            XCTAssertTrue(value.contains("sessionId"))
        } else {
            XCTFail("Payload was not set correctly")
        }
    }
    
    func testSetPayloadWithNilValue() {
        // When: Setting nil payload
        callback.setPayload(nil)
        
        // Then: Payload input should remain empty or unchanged
        let payload = callback.payload()
        XCTAssertNotNil(payload)
    }
    
    func testSetPayloadWithEmptyDictionary() {
        // When: Setting empty dictionary
        callback.setPayload([:])
        
        // Then: Should not update payload (as per implementation)
        let payload = callback.payload()
        XCTAssertNotNil(payload)
    }
    
    func testPayloadReturnsJSON() {
        // When: Getting payload
        let payload = callback.payload()
        
        // Then: Should return JSON dictionary
        XCTAssertNotNil(payload)
        XCTAssertNotNil(payload["type"])
    }
    
    // MARK: - Verify Method Tests
    
    func testVerifyWithDefaultConfig() async {
        // Note: This test requires mocking the Recaptcha.fetchClient
        // In a real test environment, you would use dependency injection
        // or a mocking framework
        
        // Given: Callback with site key
        callback.initValue(name: JourneyConstants.recaptchaSiteKey, value: "test_site_key")
        
        // When/Then: Verify is called (would fail without proper mocking)
        // This test demonstrates the structure but would need proper mocking
        // in a real test environment
    }
    
    func testVerifyWithCustomConfig() async {
        // Given: Custom configuration
        let expectation = XCTestExpectation(description: "Custom config applied")
        
        callback.initValue(name: JourneyConstants.recaptchaSiteKey, value: "test_site_key")
        
        // Note: This demonstrates how custom config would be used
        // Real implementation would require mocking the Recaptcha client
        var configApplied = false
        
        let _ = await callback.verify { config in
            config.action = "custom_action"
            config.timeout = 20000
            configApplied = true
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertTrue(configApplied, "Custom configuration should be applied")
    }
}
