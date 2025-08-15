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

class JourneyE2ETests: JourneyE2EBaseTest, @unchecked Sendable {
    
    var logger = LogManager.logger
    
    func testSuccessfulLogin() async throws {
        let node = try await handleLoginCallbacks(journey: defaultJourney, treeName: "Login")
        
        // Assert success node
        XCTAssertTrue(node is SuccessNode, "Expected a SuccessNode, but got \(type(of: node))")
        
        // Check the session object
        let session = await defaultJourney.session()
        XCTAssertNotNil(session)
        XCTAssertNotNil(session?.value, "Session should contain a value after login")
        XCTAssertEqual(session?.realm, "/alpha")
        XCTAssertEqual(session?.successUrl, "/enduser/?realm=/alpha")
        
        // Check the user object
        let journeyUser = await defaultJourney.journeyUser()
        XCTAssertNotNil(journeyUser)
        
        let token = await journeyUser?.token()
        XCTAssertNotNil(token, "User should have a valid access token")

        // Log the session value for debug purposes -
        let userSession = journeyUser?.session
        logger.d("User session: \(userSession?.value ?? "<nil>")")

        // User session should match journey session
        XCTAssertEqual(journeyUser?.session?.value, session?.value)
        
        logger.d("Journey session: \(session?.value ?? "<nil>")")
    }

    func testSuccessfulLoginWithNoSession() async throws {
        // Start the journey with noSession = true
        var node = await defaultJourney.start("Login") { options in
            options.noSession = true
        }
        
        guard let continueNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode but got \(type(of: node))")
            return
        }
        
        // Handle login callbacks
        guard let usernameCallback = continueNode.callbacks.first as? NameCallback,
              let passwordCallback = continueNode.callbacks.last as? PasswordCallback else {
            XCTFail("Missing expected callbacks")
            return
        }
        
        usernameCallback.name = username
        passwordCallback.password = password
        
        // Proceed to the next node
        node = await continueNode.next()
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after login")

        // Assert that no session is created
        let session = await defaultJourney.session()
        XCTAssertNil(session, "Expected no session when noSession = true")
    }
    
    func testSessionSignOff() async throws {
        // Start the journey and log in
        let node = try await handleLoginCallbacks()
        
        // Assert SuccessNode
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after login")

        // Session should not be nil
        var session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected session to exist after login")
     
        let signOffResult = await defaultJourney.journeySignOff()
        switch signOffResult {
        case .success:
            break // Sign-off succeeded
        case .failure(let error):
            XCTFail("Sign-off failed with error: \(error)")
        }

        // After sign-off, session should be nil
        session = await defaultJourney.session()
        XCTAssertNil(session, "Expected session to be nil after sign-off")
    }
    
    func testHandleError() async throws {
        // Start the journey
        var node = await defaultJourney.start("Login")
        
        guard let continueNode = node as? ContinueNode else {
            XCTFail("Expected ContinueNode but got \(type(of: node))")
            return
        }
        
        // Provide invalid login credentials
        if let usernameCallback = continueNode.callbacks.first as? NameCallback,
           let passwordCallback = continueNode.callbacks.last as? PasswordCallback {
            usernameCallback.name = "invalidUser"
            passwordCallback.password = "invalidPassword"
        } else {
            XCTFail("Callbacks are not of expected types")
            return
        }
        
        // Proceed to the next node
        node = await continueNode.next()
        
        // Verify it's an ErrorNode
        XCTAssertTrue(node is ErrorNode)
        
        guard let errorNode = node as? ErrorNode else {
            XCTFail("Expected ErrorNode but got \(type(of: node))")
            return
        }

        // Assert the error message
        XCTAssertEqual(errorNode.message, "Login failure")
    }
    
    func testHandleFailure() async throws {
        // Create a custom Journey with a short timeout
        let journey = Journey.createJourney { options in
            options.serverUrl = self.config.serverUrl
            options.realm = self.config.realm
            options.cookie = self.config.cookieName
            options.timeout = 0.001
        }

        let node = await journey.start("Login")

        guard let failureNode = node as? FailureNode else {
            XCTFail("Expected FailureNode but got \(type(of: node))")
            return
        }

        // Check if the cause is an HttpRequestTimeoutException (or equivalent)
        let cause = failureNode.cause
        XCTAssertTrue(cause.localizedDescription.contains("The request timed out"))
    }
    
    func testUserToken() async throws {
        let node = try await handleLoginCallbacks(journey: defaultJourney, treeName: "Login")

        // Assert successful login
        XCTAssertTrue(node is SuccessNode)

        // Get the token
        guard case let .success(token) = await defaultJourney.journeyUser()?.token() else {
            XCTFail("Expected token retrieval to succeed")
            return
        }

        // Token assertions
        XCTAssertNotNil(token)
        XCTAssertFalse(token.accessToken.isEmpty)
        XCTAssertNotNil(token.idToken)
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertTrue(token.scope?.contains("openid") ?? false)
        XCTAssertTrue(token.scope?.contains("profile") ?? false)
        XCTAssertTrue(token.scope?.contains("email") ?? false)
        XCTAssertFalse(token.isExpired)
        XCTAssertGreaterThan(token.expiresIn, 0)

        // Ensure token is stable and repeatable
        guard case let .success(token2) = await defaultJourney.journeyUser()?.token() else {
            XCTFail("Expected second token retrieval to succeed")
            return
        }
        XCTAssertEqual(token.accessToken, token2.accessToken)
    }
    
    func testUserTokenAuthorizeFailure() async throws {
        // Create a journey with an invalid OIDC client ID
        let invalidOidcClientJourney = Journey.createJourney { config in
            config.serverUrl = self.config.serverUrl
            config.realm = self.config.realm
            config.cookie = self.config.cookieName
            config.module(PingJourney.OidcModule.config) { oidcValue in
                oidcValue.discoveryEndpoint = self.config.discoveryEndpoint
                oidcValue.redirectUri = self.config.redirectUri
                oidcValue.clientId = "InvalidClientId" // Intentionally incorrect
                oidcValue.scopes = Set(self.config.scopes)
            }
        }

        // Start the journey and provide valid credentials
        let node = try await handleLoginCallbacks(journey: invalidOidcClientJourney, treeName: "Login")

        // Expect success node (authentication succeeded, OIDC will fail later)
        XCTAssertTrue(node is SuccessNode)

        // Attempt to fetch the token and expect failure
        guard case let .failure(error) = await invalidOidcClientJourney.journeyUser()?.token() else {
            XCTFail("Expected token retrieval to fail")
            return
        }
        
        XCTAssertTrue(error is OidcError, "Expected OidcError but got \(type(of: error))")
        XCTAssertTrue(error.errorMessage.contains("invalid_client"), "Unexpected error message: \(error.errorMessage)")
    }
    
    func testUserTokenRefresh() async throws {
        // Start the default journey and login successfully
        let node = try await handleLoginCallbacks()
        XCTAssertTrue(node is SuccessNode)

        // Get access token
        let result1 = await defaultJourney.journeyUser()?.token()
        XCTAssertNotNil(result1)

        let result2 = await defaultJourney.journeyUser()?.refresh()
        XCTAssertNotNil(result2)

        var token1: Token? = nil
        switch result1! {
        case .success(let token):
            token1 = token
        case .failure:
            XCTFail("Failed to obtain access token")
        }
        XCTAssertNotNil(token1)
        
        var token2: Token? = nil
        switch result2! {
        case .success(let token):
            token2 = token
        case .failure:
            XCTFail("Failed to obtain access token")
        }
        XCTAssertNotNil(token2)
        
        // Ensure tokens are different
        XCTAssertNotEqual(token1?.accessToken, token2?.accessToken)
    }
    
    func testUserTokenRevoke() async throws {
        // Start the default journey and
        let node = try await handleLoginCallbacks()
        XCTAssertTrue(node is SuccessNode)

        // Get the current access token
        let result1 = await defaultJourney.journeyUser()?.token()
        var token1: Token? = nil
        
        switch result1! {
        case .success(let token):
            token1 = token
        case .failure:
            XCTFail("Failed to obtain access token")
        }
        XCTAssertNotNil(token1)
        
        // Revoke the token
        await defaultJourney.journeyUser()?.revoke()

        let result2 = await defaultJourney.journeyUser()?.token()
        var token2: Token? = nil
        
        switch result2! {
        case .success(let token):
            token2 = token
        case .failure(let error):
            XCTFail("Failed to obtain access token: \(error.errorMessage)")
        }
        XCTAssertNotNil(token2)
        
        // Tokens should be different
        XCTAssertNotEqual(token1?.accessToken, token2?.accessToken)
    }
    
    func testUserInfo() async throws {
        // Start the journey and login with valid credentials
        let node = try await handleLoginCallbacks(journey: defaultJourney, treeName: "Login")
        XCTAssertTrue(node is SuccessNode)

        // Get user info
        guard case let .success(userInfo) = await defaultJourney.journeyUser()?.userinfo(cache: true) else {
            XCTFail("Expected successful userInfo retrieval")
            return
        }

        logger.d("User Info: \(userInfo)")

        // Validate user info fields
        XCTAssertNotNil(userInfo["sub"])
        XCTAssertNotNil(userInfo["email"])
        XCTAssertNotNil(userInfo["name"])
        XCTAssertNotNil(userInfo["given_name"])
        XCTAssertNotNil(userInfo["family_name"])
    }
    
    func testUserLogout() async throws {
        // Start the journey and log in
        let node = try await handleLoginCallbacks()
        
        // Assert SuccessNode
        XCTAssertTrue(node is SuccessNode, "Expected SuccessNode after login")

        // Session should not be nil
        var session = await defaultJourney.session()
        XCTAssertNotNil(session, "Expected session to exist after login")
     
        // User should have access token
        guard case let .success(token) = await defaultJourney.journeyUser()?.token() else {
            XCTFail("Expected user to have an access token")
            return
        }
        XCTAssertNotNil(token, "User access token should not be nil")
        
        // Logout the user
        await defaultJourney?.journeyUser()?.logout()
        
        // After logout, the session should be null
        session = await defaultJourney.session()
        XCTAssertNil(session, "Expected session be nil after logout")
        
        // After logout, the journey user should be null
        let journeyUser = await defaultJourney?.journeyUser()
        XCTAssertNil(journeyUser, "journeyUser should be nil")
    }
}
