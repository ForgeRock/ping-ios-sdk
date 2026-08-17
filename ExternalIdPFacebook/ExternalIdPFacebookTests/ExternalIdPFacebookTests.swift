//
//  ExternalIdPFacebookTests.swift
//  ExternalIdPFacebookTests
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingExternalIdPFacebook
@testable import PingExternalIdP
@testable import PingNetwork
@testable import PingDavinciPlugin

final class ExternalIdPFacebookTests: XCTestCase {
    
    override func setUpWithError() throws {
        IdpCollector.registerCollector()
    }
    
    // MARK: - IdpCollector Limited Login Flag Tests
    
    @MainActor func testIdpCollectorFacebookLimitedLoginEnabledForwardsToHandler() throws {
        let jsonObject: [String: Any] = [
            "idpId": "test-id",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Facebook",
            "links": [
                "authenticate": [
                    "href": "https://example.com"
                ]
            ]
        ]
        let idpCollector = IdpCollector(with: jsonObject)
        idpCollector.facebookLimitedLoginEnabled = true
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        let configurableHandler = try XCTUnwrap(handler as? FacebookLimitedLoginConfigurable)
        XCTAssertTrue(configurableHandler.facebookLimitedLoginEnabled)
    }
    
    @MainActor func testIdpCollectorFacebookLimitedLoginDefaultsToDisabledOnHandler() throws {
        let jsonObject: [String: Any] = [
            "idpId": "test-id",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Facebook",
            "links": [
                "authenticate": [
                    "href": "https://example.com"
                ]
            ]
        ]
        let idpCollector = IdpCollector(with: jsonObject)
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        let configurableHandler = try XCTUnwrap(handler as? FacebookLimitedLoginConfigurable)
        XCTAssertFalse(configurableHandler.facebookLimitedLoginEnabled)
    }
    
    // MARK: - IdpCollector Tests
    
    @MainActor func testidpCollectorParsingFacebook() throws {
        let jsonObject: [String: Any] = [
            "idpId" : "1a1198fa0290d505d7cc49bb8e9fcb68",
            "idpType" : "FACEBOOK",
            "type" : "SOCIAL_LOGIN_BUTTON",
            "label" : "Sign in with Facebook",
            "idpEnabled" : true,
            "links" : [
                "authenticate" : [
                    "href" : "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/1a1198fa0290d505d7cc49bb8e9fcb68/capabilities/loginFirstFactor?interactionId=00caf721-c3f9-4880-8fe1-43e68b8c8691&interactionToken=c99b1e4854aefd5429d032b5446d4d5152826b1728eb047f89c727b58e2d237e944357c347eed50c43125d4a8a05afce5150d728e148b7d9f6dcff0403f6aa3dbc50598c0c48a3527bb72313136101c7a07c39e34ab54d34d7bbc891488cb0b1bbe6f841aeb5d59071366a46fa84f3d18fa08779dd2517e809fa9f1513793005&skRefreshToken=true"
                ]
            ]
        ]
        
        let idpCollector = IdpCollector(with: jsonObject)
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        XCTAssertTrue(idpCollector.idpType == "FACEBOOK")
        XCTAssertTrue(idpCollector.link?.absoluteString == "https://auth.pingone.com/c2a669c0-c396-4544-994d-9c6eb3fb1602/davinci/connections/1a1198fa0290d505d7cc49bb8e9fcb68/capabilities/loginFirstFactor?interactionId=00caf721-c3f9-4880-8fe1-43e68b8c8691&interactionToken=c99b1e4854aefd5429d032b5446d4d5152826b1728eb047f89c727b58e2d237e944357c347eed50c43125d4a8a05afce5150d728e148b7d9f6dcff0403f6aa3dbc50598c0c48a3527bb72313136101c7a07c39e34ab54d34d7bbc891488cb0b1bbe6f841aeb5d59071366a46fa84f3d18fa08779dd2517e809fa9f1513793005&skRefreshToken=true")
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? FacebookRequestHandler)
    }
    
    // MARK: - FacebookHandler Tests
    
    @MainActor func testFacebookHandlerTokenType() {
        let handler = FacebookHandler()
        XCTAssertEqual(handler.tokenType, IdpConstants.access_token)
    }
    
    @MainActor func testFacebookHandlerInitialization() {
        let handler = FacebookHandler()
        XCTAssertNotNil(handler)
    }
    
    // MARK: - FacebookRequestHandler Tests
    
    @MainActor func testFacebookRequestHandlerInitialization() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        XCTAssertNotNil(handler)
    }
    
    @MainActor func testFacebookRequestHandlerLimitedLoginDefaultsToDisabled() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        XCTAssertFalse(handler.facebookLimitedLoginEnabled)
    }
    
    @MainActor func testFacebookRequestHandlerLimitedLoginCanBeEnabled() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        handler.facebookLimitedLoginEnabled = true
        XCTAssertTrue(handler.facebookLimitedLoginEnabled)
    }
    
    // MARK: - FacebookHandlerUtils Tests
    
    @MainActor func testFacebookHandlerUtilsAuthorizeThrowsWithNilConfiguration() async {
        let idpClient = IdpClient(clientId: "test", scopes: ["email"])
        
        do {
            _ = try await FacebookHandlerUtils.authorize(idpClient: idpClient, configuration: nil, manager: nil)
            XCTFail("Expected error to be thrown with nil configuration")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    @MainActor func testFacebookHandlerUtilsAuthorizeThrowsWhenNoViewController() async {
        let idpClient = IdpClient(clientId: "test", scopes: ["email"])
        
        do {
            _ = try await FacebookHandlerUtils.authorize(idpClient: idpClient, configuration: nil, manager: nil)
            XCTFail("Expected error to be thrown when no view controller is available")
        } catch {
            // Expected - validation fails with no view controller or invalid config
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Facebook Limited Login Mode Tests
    
    @MainActor func testFacebookHandlerTokenTypeWhenLimitedLoginEnabled() {
        let handler = FacebookHandler()
        handler.facebookLimitedLoginEnabled = true
        XCTAssertEqual(handler.tokenType, IdpConstants.id_token)
    }
    
    @MainActor func testFacebookHandlerTokenTypeWhenLimitedLoginDisabled() {
        let handler = FacebookHandler()
        XCTAssertEqual(handler.tokenType, IdpConstants.access_token)
    }
    
    @MainActor func testFacebookHandlerUtilsLimitedThrowsWithNilConfiguration() async {
        let idpClient = IdpClient(clientId: "test", scopes: ["email"])

        do {
            _ = try await FacebookHandlerUtils.authorize(idpClient: idpClient, configuration: nil, manager: nil, isLimited: true)
            XCTFail("Expected error to be thrown with nil configuration in limited mode")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - IdpCallback fb-limited Provider Matching Tests

    @MainActor func testIdpCallbackMatchesFbLimitedProviderBeforeFacebook() throws {
        let callback = IdpCallback()
        callback.initValue(name: "provider", value: "fb-limited")
        let handler = callback.getDefaultIdpHandler()
        let configurableHandler = try XCTUnwrap(handler as? FacebookLimitedLoginConfigurable)
        XCTAssertTrue(configurableHandler.facebookLimitedLoginEnabled)
    }

    @MainActor func testIdpCallbackMatchesPlainFacebookProviderAsClassic() throws {
        let callback = IdpCallback()
        callback.initValue(name: "provider", value: "facebook")
        let handler = callback.getDefaultIdpHandler()
        let configurableHandler = try XCTUnwrap(handler as? FacebookLimitedLoginConfigurable)
        XCTAssertFalse(configurableHandler.facebookLimitedLoginEnabled)
    }

}
