// 
//  ReCaptchaEnterpriseCallbackTests.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingReCaptchaEnterprise
@testable import PingJourney

class ReCaptchaEnterpriseConfigTests: XCTestCase {
    
    var config: ReCaptchaEnterpriseConfig!
    
    override func setUp() {
        super.setUp()
        config = ReCaptchaEnterpriseConfig()
    }
    
    override func tearDown() {
        config = nil
        super.tearDown()
    }
    
    func testDefaultConfiguration() {
        // Then: Default values should be set
        XCTAssertEqual(config.action, ReCaptchaEnterpriseConstants.defaultAction)
        XCTAssertEqual(config.timeout, ReCaptchaEnterpriseConstants.defaultTimeout)
        XCTAssertNotNil(config.logger)
        XCTAssertNil(config.payload)
    }
    
    func testCustomAction() {
        // When: Setting custom action
        config.action = "checkout"
        
        // Then: Action should be updated
        XCTAssertEqual(config.action, "checkout")
    }
    
    func testCustomTimeout() {
        // When: Setting custom timeout
        config.timeout = 30000
        
        // Then: Timeout should be updated
        XCTAssertEqual(config.timeout, 30000)
    }
    
    func testCustomPayload() {
        // When: Setting custom payload
        let customPayload: [String: Any] = [
            "customField": "customValue",
            "userId": 123
        ]
        config.payload = customPayload
        
        // Then: Payload should be set
        XCTAssertNotNil(config.payload)
        XCTAssertEqual(config.payload?["customField"] as? String, "customValue")
        XCTAssertEqual(config.payload?["userId"] as? Int, 123)
    }
    
    func testConfigurationIsIndependent() {
        // Given: Two separate configs
        let config1 = ReCaptchaEnterpriseConfig()
        let config2 = ReCaptchaEnterpriseConfig()
        
        // When: Modifying one config
        config1.action = "login"
        config2.action = "signup"
        
        // Then: Configs should be independent
        XCTAssertEqual(config1.action, "login")
        XCTAssertEqual(config2.action, "signup")
    }
}
