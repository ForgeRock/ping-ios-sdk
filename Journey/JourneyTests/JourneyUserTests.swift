//
//  JourneyUserTests.swift
//  JourneyTests
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import XCTest
@testable import PingJourney
@testable import PingOidc
@testable import PingOrchestrate

fileprivate extension SharedContext.Keys {
    /// The key used to store the PKCE value in the shared context.
    static let pkceKey = "com.pingidentity.journey.PKCE"
    
    /// The key used to store the user in the shared context.
    static let userKey = "com.pingidentity.journey.User"
    
    /// The key used to store the OIDC client configuration in the shared context.
    static let oidcClientConfigKey = "com.pingidentity.journey.OidcClientConfig"
}

final class UserTests: XCTestCase {
    
    // MARK: - Mock Classes
    
    class MockUser: User, @unchecked Sendable {
        
        
        func logout() async {
            
        }
        
        var tokenResult: Result<Token, OidcError> = .success(Token(accessToken: "test-token", tokenType: nil, scope: "", expiresIn: 100, refreshToken: nil, idToken: nil))
        var userinfoResult: Result<UserInfo, OidcError> = .success(UserInfo())
        var wasRevokeCalled = false
        
        func token() async -> Result<Token, OidcError> {
            return tokenResult
        }
        
        func refresh() async -> Result<Token, OidcError> {
            return tokenResult
        }
        
        func revoke() async {
            wasRevokeCalled = true
        }
        
        func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
            return userinfoResult
        }
    }
    
    class MockSession: Session, @unchecked Sendable {
        let sessionValue: String
        
        init(value: String = "test-session") {
            self.sessionValue = value
        }
        
        var value: String {
            return sessionValue
        }
    }
    
    // MARK: - Journey User Tests
    
    func testJourneyUserWithCachedUser() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        journey.sharedContext.set(key: SharedContext.Keys.userKey, value: mockUser)
        
        let user = await journey.journeyUser()
        XCTAssertNotNil(user)
        XCTAssertTrue(user is MockUser)
    }
    
    func testJourneyUserWithOidcConfig() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let oidcConfig = OidcClientConfig()
        journey.sharedContext.set(key: SharedContext.Keys.oidcClientConfigKey, value: oidcConfig)
        
        let user = await journey.journeyUser()
        XCTAssertNil(user) // Should be nil since no session exists
    }
    
    func testJourneyUserWithNoUserOrSession() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let user = await journey.journeyUser()
        XCTAssertNil(user)
    }
    
    // MARK: - PrepareUser Tests
    
    func testPrepareUser() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession()
        
        let userDelegate = await journey.prepareUser(journey: journey, user: mockUser, session: mockSession)
        
        XCTAssertNotNil(userDelegate)
    }
    
    // MARK: - SuccessNode Tests
    
    func testSuccessNodeWithNonUserSession() {
        let mockSession = MockSession()
        let successNode = SuccessNode(session: mockSession)
        
        XCTAssertNil(successNode.user)
    }
    
    // MARK: - UserDelegate Tests
    
    func testUserDelegateLogout() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession()
        
        let userDelegate = UserDelegate(journey: journey, user: mockUser, session: mockSession)
        journey.sharedContext.set(key: SharedContext.Keys.userKey, value: userDelegate)
        
        await userDelegate.logout()
        
        let cachedUser = journey.sharedContext.get(key: SharedContext.Keys.userKey)
        XCTAssertNil(cachedUser)
    }
    
    func testUserDelegateToken() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession()
        
        let userDelegate = UserDelegate(journey: journey, user: mockUser, session: mockSession)
        
        let tokenResult = await userDelegate.token()
        if case .success(let token) = tokenResult {
            XCTAssertEqual(token.accessToken, "test-token")
        } else {
            XCTFail("Expected success token result")
        }
    }
    
    func testUserDelegateRevoke() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession()
        
        let userDelegate = UserDelegate(journey: journey, user: mockUser, session: mockSession)
        
        await userDelegate.revoke()
        XCTAssertTrue(mockUser.wasRevokeCalled)
    }
    
    func testUserDelegateUserinfo() async {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession()
        
        let userDelegate = UserDelegate(journey: journey, user: mockUser, session: mockSession)
        
        let userinfoResult = await userDelegate.userinfo(cache: true)
        XCTAssertNoThrow(try userinfoResult.get())
    }
    
    func testUserDelegateSessionValue() {
        let journey = Journey.createJourney { config in
            config.serverUrl = "https://test.com"
            config.realm = "test-realm"
        }
        let mockUser = MockUser()
        let mockSession = MockSession(value: "test-session-value")
        
        let userDelegate = UserDelegate(journey: journey, user: mockUser, session: mockSession)
        
        XCTAssertEqual(userDelegate.value, "test-session-value")
    }
}
