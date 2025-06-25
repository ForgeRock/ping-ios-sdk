//
//  User.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import PingOidc
import PingOrchestrate

extension Journey {
    /// Retrieves the current user associated with the journey.
    /// This method checks if a user is already cached in the shared context.
    /// If not, it attempts to initialize the journey and retrieve the user from the session.
    /// - Returns: An optional User instance if available, otherwise nil.
    public func journeyUser() async -> User? {
        try? await initialize()
        
        if let cachedUser = self.sharedContext.get(key: SharedContext.Keys.userKey) as? User {
            return cachedUser
        }
        
        if ((await session()) != nil) {
            if let oidcClientConfig = self.sharedContext.get(key: SharedContext.Keys.oidcClientConfigKey) as? OidcClientConfig {
                return await prepareUser(journey: self, user: OidcUser(config: oidcClientConfig))
            }
        }
        return nil
    }
    
    /// Prepares a UserDelegate for the given journey and user.
    /// This method creates a UserDelegate instance and caches it in the shared context.
    /// - Parameters:
    /// - journey: The Journey instance.
    /// - user: The User instance to be prepared.
    /// - session: The Session instance, defaulting to an empty session.
    /// - Returns: A UserDelegate instance that wraps the provided user and session.
    func prepareUser(
        journey: Journey,
        user: User,
        session: Session = EmptySession()
    ) async -> UserDelegate {
        let userDelegate = UserDelegate(journey: journey, user: user, session: session)
        // Cache the user in the context
        self.sharedContext.set(key: SharedContext.Keys.userKey, value: userDelegate)
        return userDelegate
    }
}

extension SuccessNode {
    /// Extension property for SuccessNode to cast the `SuccessNode.session` to a User.
    public var user: User? {
        return session as? User
    }
}

/// Struct representing a UserDelegate.
/// This struct is a delegate for the User and Session interfaces.
/// It overrides the logout function to remove the cached user from the context and sign off the user.
/// - property daVinci: The DaVinci instance.
/// - property user: The user.
/// - property session: The session.
struct UserDelegate: User, Session, Sendable {
    private let journey: Journey
    private let user: User
    private let session: Session
    
    init(journey: Journey, user: User, session: Session) {
        self.journey = journey
        self.user = user
        self.session = session
    }
    
    /// Method to log out the user.
    /// This method removes the cached user from the context and signs off the user.
    func logout() async {
        // remove the cached user from the context
        _ = journey.sharedContext.removeValue(forKey: SharedContext.Keys.userKey)
        // instead of calling `OidcClient.endSession` directly, we call `DaVinci.signOff` to sign off the user
        _ = await journey.signOff()
    }
    
    /// User token retrieval method.
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    /// Method to revoke the user's token.
    func revoke() async {
        await user.revoke()
    }
    
    /// Method to retrieve user information.
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    /// Getter to retrieve the session value.
    var value: String {
        get {
            return session.value
        }
    }
}
