// 
//  OidcWebTests.swift
//  Oidc
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc
import PingBrowser
import PingOrchestrate

class OidcWebTests: XCTestCase {
    var oidcWeb: OidcWeb?
    
    override func setUp() {
        super.setUp()
        
        self.oidcWeb = OidcWeb.createOidcWeb { config in
            config.browserMode = .login
            config.browserType = .authSession
            config.module(OidcModule.config) { oidcValue in
                oidcValue.clientId = "TestClientId"
                oidcValue.scopes = Set("openid profile email".split(separator: " ").map { String($0) })
                oidcValue.redirectUri = "https://example.com/callback"
                oidcValue.discoveryEndpoint = "https://example.com/.well-known/openid-configuration"
            }
        }
    }
    
    func testOidcWeb() throws {
        guard let oidcWeb = self.oidcWeb else {
            XCTFail("Failed to create Journey instance")
            return
        }
        
        XCTAssertEqual(oidcWeb.config.modules.count, 2)
        XCTAssertEqual(oidcWeb.signOffHandlers.count, 1)
        XCTAssertEqual(oidcWeb.successHandlers.count, 1)
    }
    
    func testOidcWebConfig() throws {
        guard let oidcWeb = self.oidcWeb else {
            XCTFail("Failed to create Journey instance")
            return
        }
        
        let oidcWebConfig = oidcWeb.config as? OidcWebConfig
        XCTAssertNotNil(oidcWebConfig)
        XCTAssertEqual(oidcWebConfig?.browserMode, .login)
        XCTAssertEqual(oidcWebConfig?.browserType, .authSession)
    }
}
