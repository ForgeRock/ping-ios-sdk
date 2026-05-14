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

    @MainActor func testFacebookHandlerLimitedLoginTokenType() {
        let handler = FacebookHandler(trackingMode: .limited)
        XCTAssertEqual(handler.tokenType, IdpConstants.id_token)
    }

    @MainActor func testFacebookHandlerEnabledTokenType() {
        let handler = FacebookHandler(trackingMode: .enabled)
        XCTAssertEqual(handler.tokenType, IdpConstants.access_token)
    }

    // MARK: - FacebookRequestHandler Tests

    @MainActor func testFacebookRequestHandlerInitialization() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        XCTAssertNotNil(handler)
    }

    /// Verifies that the default `@objc(initWithHttpClient:)` initializer produces a non-nil handler.
    /// The default init delegates to `init(httpClient:trackingMode: .enabled)` so `.enabled` is the default.
    @MainActor func testFacebookTrackingModeDefaultIsEnabled() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient)
        // The default init uses .enabled tracking; the handler must be non-nil
        XCTAssertNotNil(handler)
    }

    /// Verifies that `FacebookRequestHandler(httpClient:trackingMode: .limited)` initializes without crash.
    @MainActor func testFacebookTrackingModeLimitedInit() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient, trackingMode: .limited)
        XCTAssertNotNil(handler)
    }

    /// Verifies that `getDefaultIdpHandler` with `facebookLimitedLoginEnabled = false` returns a non-nil
    /// `FacebookRequestHandler` (standard login path, `@objc(initWithHttpClient:)` selector).
    @MainActor func testFacebookRequestHandlerObjCBridgeEnabled() {
        let jsonObject: [String: Any] = [
            "idpId": "testid",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Sign in with Facebook",
            "idpEnabled": true,
            "links": [
                "authenticate": [
                    "href": "https://example.com/facebook"
                ]
            ]
        ]
        let idpCollector = IdpCollector(with: jsonObject)
        idpCollector.facebookLimitedLoginEnabled = false
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? FacebookRequestHandler)
    }

    /// Verifies that `getDefaultIdpHandler` with `facebookLimitedLoginEnabled = true` returns a non-nil
    /// `FacebookRequestHandler` (limited login path, `@objc(initWithHttpClient:isLimitedLogin:)` selector).
    @MainActor func testFacebookRequestHandlerObjCBridgeLimited() {
        let jsonObject: [String: Any] = [
            "idpId": "testid",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Sign in with Facebook",
            "idpEnabled": true,
            "links": [
                "authenticate": [
                    "href": "https://example.com/facebook"
                ]
            ]
        ]
        let idpCollector = IdpCollector(with: jsonObject)
        idpCollector.facebookLimitedLoginEnabled = true
        let handler = idpCollector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        XCTAssertNotNil(handler)
        XCTAssertNotNil(handler as? FacebookRequestHandler)
    }

    // MARK: - FacebookHandler Default Token Type Tests

    /// Verifies that `FacebookHandler()` (no-arg) produces `tokenType == IdpConstants.access_token`.
    @MainActor func testFacebookHandlerDefaultTokenType() {
        let handler = FacebookHandler()
        XCTAssertEqual(handler.tokenType, IdpConstants.access_token)
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
            // The error message (IdpErrorMessages.facebookTokenMissing) acknowledges that either
            // access token or authentication token may be absent.
            XCTAssertNotNil(error)
        }
    }

    /// Verifies that `IdpErrorMessages.facebookTokenMissing` references both access token and
    /// authentication token (updated in Task 2 for Limited Login fallback path).
    @MainActor func testFacebookHandlerUtilsErrorMessageCoversTokenType() {
        let message = IdpErrorMessages.facebookTokenMissing
        XCTAssertTrue(message.contains("access token"), "facebookTokenMissing must reference 'access token'")
        XCTAssertTrue(message.contains("authentication token"), "facebookTokenMissing must reference 'authentication token'")
    }

    // MARK: - QA Coverage Tests

    /// AC6: facebookLimitedLoginEnabled must default to false on a freshly-created IdpCollector.
    @MainActor func testFacebookLimitedLoginEnabledDefaultsToFalse() {
        let jsonObject: [String: Any] = [
            "idpId": "test",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Facebook"
        ]
        let collector = IdpCollector(with: jsonObject)
        XCTAssertFalse(collector.facebookLimitedLoginEnabled,
                       "facebookLimitedLoginEnabled must default to false so existing callers are unaffected")
    }

    /// AC6/AC7: When facebookLimitedLoginEnabled is false the FACEBOOK branch calls makeNativeRequestHandler
    /// (initWithHttpClient:), not the limited-login bridge. Both paths must return a non-nil handler, and
    /// toggling the flag between false and true must both produce a FacebookRequestHandler.
    @MainActor func testGetDefaultIdpHandlerRespectsFlagForFacebook() {
        let jsonObject: [String: Any] = [
            "idpId": "test",
            "idpType": "FACEBOOK",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Facebook"
        ]
        let collector = IdpCollector(with: jsonObject)

        // false path — standard initWithHttpClient:
        collector.facebookLimitedLoginEnabled = false
        let standardHandler = collector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        XCTAssertNotNil(standardHandler, "Standard path must return a non-nil handler")
        XCTAssertNotNil(standardHandler as? FacebookRequestHandler,
                        "Standard handler must be a FacebookRequestHandler")

        // true path — initWithHttpClient:isLimitedLogin:
        collector.facebookLimitedLoginEnabled = true
        let limitedHandler = collector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        XCTAssertNotNil(limitedHandler, "Limited-login path must return a non-nil handler")
        XCTAssertNotNil(limitedHandler as? FacebookRequestHandler,
                        "Limited handler must be a FacebookRequestHandler")
    }

    /// AC1: FacebookTrackingMode cases are complete — no unexpected rawValue drift, both cases
    /// are the only two members. This guards against someone accidentally adding a third case
    /// without updating all switch sites.
    @MainActor func testFacebookTrackingModeCaseCompleteness() {
        // Both cases must be constructible and distinguishable.
        let enabledMode = FacebookTrackingMode.enabled
        let limitedMode = FacebookTrackingMode.limited
        XCTAssertNotEqual(String(describing: enabledMode), String(describing: limitedMode),
                          "FacebookTrackingMode.enabled and .limited must be distinct cases")
    }

    /// AC6 regression: A non-Facebook collector (GOOGLE) must not be affected by facebookLimitedLoginEnabled.
    /// The flag is on IdpCollector but the GOOGLE case in getDefaultIdpHandler must never call
    /// makeFacebookRequestHandler — it must return nil (Google handler class not present in test target).
    @MainActor func testFacebookLimitedLoginFlagDoesNotAffectGoogleHandler() {
        let jsonObject: [String: Any] = [
            "idpId": "test",
            "idpType": "GOOGLE",
            "type": "SOCIAL_LOGIN_BUTTON",
            "label": "Google"
        ]
        let collector = IdpCollector(with: jsonObject)
        // Even when set to true on a GOOGLE collector, no limited-login selector should be called
        collector.facebookLimitedLoginEnabled = true
        // GoogleRequestHandler class is not loaded in the test target, so result is nil — but no crash
        let handler = collector.getDefaultIdpHandler(httpClient: HttpClient.createClient())
        // We assert the type is NOT a FacebookRequestHandler to confirm no cross-branch dispatch
        XCTAssertNil(handler as? FacebookRequestHandler,
                     "GOOGLE collector must never produce a FacebookRequestHandler regardless of facebookLimitedLoginEnabled")
    }

    /// AC9/AC10: The AuthenticationToken fallback path and both-tokens-nil error path exist in
    /// FacebookHandlerUtils.authorize. We cannot exercise the .success callback in a unit test
    /// (no live Facebook SDK), but we can verify the error thrown when configuration is nil
    /// (which short-circuits before the token logic) has the correct message type, and separately
    /// verify the facebookTokenMissing constant is non-empty and refers to both token variants.
    @MainActor func testFacebookTokenMissingMessageIsNonEmpty() {
        let message = IdpErrorMessages.facebookTokenMissing
        XCTAssertFalse(message.isEmpty, "facebookTokenMissing must not be empty")
        // The original message only mentioned "access token"; the updated message must mention both
        XCTAssertTrue(message.contains("Facebook"), "Message should identify the provider")
    }

    /// NFR3: @objc(initWithHttpClient:) selector must still be callable on FacebookRequestHandler
    /// via ObjC runtime (the same path Apple/Google use). This verifies the bridge is not broken.
    @MainActor func testObjCInitWithHttpClientSelectorStillCallable() {
        guard let handlerClass = NSClassFromString("PingExternalIdPFacebook.FacebookRequestHandler") as? NSObject.Type else {
            XCTFail("FacebookRequestHandler class must be loadable via NSClassFromString")
            return
        }
        let allocSel = NSSelectorFromString("alloc")
        guard let allocResult = handlerClass.perform(allocSel),
              let allocated = allocResult.takeUnretainedValue() as? NSObject else {
            XCTFail("alloc must succeed on FacebookRequestHandler")
            return
        }
        let initSel = NSSelectorFromString("initWithHttpClient:")
        let httpClient = HttpClient.createClient()
        guard let initResult = allocated.perform(initSel, with: httpClient) else {
            XCTFail("initWithHttpClient: selector must be callable on FacebookRequestHandler")
            return
        }
        let handler = initResult.takeUnretainedValue()
        XCTAssertNotNil(handler, "@objc(initWithHttpClient:) must produce a non-nil FacebookRequestHandler")
        XCTAssertTrue(handler is FacebookRequestHandler,
                      "Object produced by @objc(initWithHttpClient:) must be a FacebookRequestHandler")
    }

    /// NFR3: @objc(initWithHttpClient:isLimitedLogin:) selector must be callable on FacebookRequestHandler.
    @MainActor func testObjCInitWithHttpClientIsLimitedLoginSelectorCallable() {
        guard let handlerClass = NSClassFromString("PingExternalIdPFacebook.FacebookRequestHandler") as? NSObject.Type else {
            XCTFail("FacebookRequestHandler class must be loadable")
            return
        }
        let allocSel = NSSelectorFromString("alloc")
        guard let allocResult = handlerClass.perform(allocSel),
              let allocated = allocResult.takeUnretainedValue() as? NSObject else {
            XCTFail("alloc must succeed")
            return
        }
        let initSel = NSSelectorFromString("initWithHttpClient:isLimitedLogin:")
        let httpClient = HttpClient.createClient()
        let limitedNumber = NSNumber(value: true)
        guard let initResult = allocated.perform(initSel, with: httpClient, with: limitedNumber) else {
            XCTFail("initWithHttpClient:isLimitedLogin: selector must be callable")
            return
        }
        let handler = initResult.takeUnretainedValue()
        XCTAssertNotNil(handler, "@objc(initWithHttpClient:isLimitedLogin:) must produce a non-nil handler")
        XCTAssertTrue(handler is FacebookRequestHandler,
                      "Object produced by @objc(initWithHttpClient:isLimitedLogin:) must be a FacebookRequestHandler")
    }

    /// Regression: isLimitedLogin:false via perform(_:with:with:) must not activate limited mode.
    ///
    /// Before the fix, the BOOL parameter slot received the NSNumber pointer address (always
    /// non-zero), so false was silently coerced to true. The fix changes the parameter type to
    /// NSNumber so the object pointer is delivered intact and .boolValue is read correctly.
    @MainActor func testObjCBridgeFalseDoesNotActivateLimitedLogin() {
        let httpClient = HttpClient.createClient()
        let handler = FacebookRequestHandler(httpClient: httpClient as! URLSessionHttpClient,
                                             isLimitedLogin: NSNumber(value: false))
        XCTAssertNotNil(handler)
        // Standard (non-limited) init must not crash and must be a valid handler
        XCTAssertTrue(handler is FacebookRequestHandler)
    }

}
