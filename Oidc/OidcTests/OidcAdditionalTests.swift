//
//  OidcAdditionalTests.swift
//  OidcTests
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import XCTest
@testable import PingOidc

// MARK: - OpenIdConfiguration Tests

final class OpenIdConfigurationTests: XCTestCase {
    
    func testDecodingFromJSON() throws {
        let json = """
        {
            "authorization_endpoint": "https://auth.example.com/authorize",
            "token_endpoint": "https://auth.example.com/token",
            "userinfo_endpoint": "https://auth.example.com/userinfo",
            "end_session_endpoint": "https://auth.example.com/logout",
            "revocation_endpoint": "https://auth.example.com/revoke"
        }
        """.data(using: .utf8)!
        
        let config = try JSONDecoder().decode(OpenIdConfiguration.self, from: json)
        
        XCTAssertEqual(config.authorizationEndpoint, "https://auth.example.com/authorize")
        XCTAssertEqual(config.tokenEndpoint, "https://auth.example.com/token")
        XCTAssertEqual(config.userinfoEndpoint, "https://auth.example.com/userinfo")
        XCTAssertEqual(config.endSessionEndpoint, "https://auth.example.com/logout")
        XCTAssertEqual(config.revocationEndpoint, "https://auth.example.com/revoke")
        XCTAssertNil(config.pingEndsessionEndpoint)
    }
    
    func testDecodingWithPingEndSessionEndpoint() throws {
        let json = """
        {
            "authorization_endpoint": "https://auth.example.com/authorize",
            "token_endpoint": "https://auth.example.com/token",
            "userinfo_endpoint": "https://auth.example.com/userinfo",
            "end_session_endpoint": "https://auth.example.com/logout",
            "revocation_endpoint": "https://auth.example.com/revoke",
            "ping_end_idp_session_endpoint": "https://auth.example.com/ping_logout"
        }
        """.data(using: .utf8)!
        
        let config = try JSONDecoder().decode(OpenIdConfiguration.self, from: json)
        
        XCTAssertEqual(config.pingEndsessionEndpoint, "https://auth.example.com/ping_logout")
    }
    
    func testEncodingAndDecoding() throws {
        let json = """
        {
            "authorization_endpoint": "https://auth.example.com/authorize",
            "token_endpoint": "https://auth.example.com/token",
            "userinfo_endpoint": "https://auth.example.com/userinfo",
            "end_session_endpoint": "https://auth.example.com/logout",
            "revocation_endpoint": "https://auth.example.com/revoke"
        }
        """.data(using: .utf8)!
        
        let config = try JSONDecoder().decode(OpenIdConfiguration.self, from: json)
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(OpenIdConfiguration.self, from: encoded)
        
        XCTAssertEqual(decoded.authorizationEndpoint, config.authorizationEndpoint)
        XCTAssertEqual(decoded.tokenEndpoint, config.tokenEndpoint)
        XCTAssertEqual(decoded.userinfoEndpoint, config.userinfoEndpoint)
        XCTAssertEqual(decoded.endSessionEndpoint, config.endSessionEndpoint)
        XCTAssertEqual(decoded.revocationEndpoint, config.revocationEndpoint)
    }
}

// MARK: - DefaultAgent Tests

final class DefaultAgentTests: XCTestCase {
    
    func testInit() {
        let agent = DefaultAgent()
        XCTAssertNotNil(agent)
    }
    
    func testConfigReturnsVoidFunction() {
        let agent = DefaultAgent()
        let configFunc = agent.config()
        // Just verify it returns a function and can be called
        configFunc()
        XCTAssertTrue(true)
    }
    
    func testEndSessionReturnsFalse() async throws {
        let agent = DefaultAgent()
        let oidcClientConfig = OidcClientConfig()
        let oidcConfig = OidcConfig(oidcClientConfig: oidcClientConfig, config: ())
        
        let result = try await agent.endSession(oidcConfig: oidcConfig, idToken: "test_token")
        XCTAssertFalse(result)
    }
    
    func testAuthorizeThrowsError() async {
        let agent = DefaultAgent()
        let oidcClientConfig = OidcClientConfig()
        let oidcConfig = OidcConfig(oidcClientConfig: oidcClientConfig, config: ())
        
        do {
            _ = try await agent.authorize(oidcConfig: oidcConfig)
            XCTFail("Should have thrown an error")
        } catch let error as OidcError {
            XCTAssertEqual(error.errorMessage, "Authorization error: No AuthCode is available.")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - OidcConfig Tests

final class OidcConfigTests: XCTestCase {
    
    func testInit() {
        let oidcClientConfig = OidcClientConfig()
        oidcClientConfig.clientId = "test-client-id"
        
        let oidcConfig = OidcConfig(oidcClientConfig: oidcClientConfig, config: "test-config")
        
        XCTAssertEqual(oidcConfig.oidcClientConfig.clientId, "test-client-id")
        XCTAssertEqual(oidcConfig.config, "test-config")
    }
}

// MARK: - AgentDelegate Tests

final class AgentDelegateTests: XCTestCase {
    
    func testInit() {
        let agent = DefaultAgent()
        let oidcClientConfig = OidcClientConfig()
        
        let delegate = AgentDelegate(agent: agent, agentConfig: (), oidcClientConfig: oidcClientConfig)
        
        XCTAssertNotNil(delegate)
    }
    
    func testEndSessionDelegates() async throws {
        let agent = DefaultAgent()
        let oidcClientConfig = OidcClientConfig()
        
        let delegate = AgentDelegate(agent: agent, agentConfig: (), oidcClientConfig: oidcClientConfig)
        
        let result = try await delegate.endSession(idToken: "test_token")
        XCTAssertFalse(result)
    }
    
    func testAuthenticateThrowsWhenUsingDefaultAgent() async {
        let agent = DefaultAgent()
        let oidcClientConfig = OidcClientConfig()
        
        let delegate = AgentDelegate(agent: agent, agentConfig: (), oidcClientConfig: oidcClientConfig)
        
        do {
            _ = try await delegate.authenticate()
            XCTFail("Should have thrown an error")
        } catch let error as OidcError {
            XCTAssertEqual(error.errorMessage, "Authorization error: No AuthCode is available.")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
