//
//  User.swift
//  Journey
//
// Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
// This software may be modified and distributed under the terms
// of the MIT license. See the LICENSE file for details.
//

import PingOidc
import PingOrchestrate
import PingJourneyPlugin

extension Journey {
    /// Returns the current authenticated user for this Journey, if available.
    ///
    /// This will:
    /// - Initialize the Journey if needed
    /// - Return a cached user if present
    /// - If a session exists, prepare and cache a `UserDelegate` backed by `OidcUser`
    ///
    /// - Returns: A `User` if available, otherwise `nil`.
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
    
    /// Prepares and caches a `UserDelegate` for this Journey and the provided `User`.
    ///
    /// - Parameters:
    ///   - journey: The Journey instance.
    ///   - user: The user implementation to wrap (typically `OidcUser`).
    ///   - session: The session to associate with the user, defaults to `EmptySession()`.
    /// - Returns: The prepared `UserDelegate`.
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
    /// Convenience accessor that attempts to cast the session to a `User`.
    public var user: User? {
        return session as? User
    }
}

extension User {
    /// Convenience accessor that attempts to cast the user to a `Session`.
    public var session: Session? {
        return self as? Session
    }
}

/// A delegate that adapts a `User` to also conform to `Session` while
/// providing Journey-aware logout behavior.
///
/// On `logout()`, the cached user is removed and `journey.signOff()` is invoked.
struct UserDelegate: User, Session, Sendable {
    /// The Journey instance associated with this user.
    private let journey: Journey
    /// The underlying user implementation (e.g., `OidcUser`).
    private let user: User
    /// The associated session implementation.
    private let session: Session
    
    /// Creates a new `UserDelegate`.
    /// - Parameters:
    ///   - journey: The Journey instance.
    ///   - user: The underlying user.
    ///   - session: The associated session.
    init(journey: Journey, user: User, session: Session) {
        self.journey = journey
        self.user = user
        self.session = session
    }
    
    /// Logs out the user:
    /// - Removes the cached user from the shared context
    /// - Calls `journey.signOff()` to end the Journey session
    func logout() async {
        // remove the cached user from the context
        _ = journey.sharedContext.removeValue(forKey: SharedContext.Keys.userKey)
        // instead of calling `OidcClient.endSession` directly, we call `journey.signOff` to sign off the user
        _ = await journey.signOff()
    }
    
    /// Retrieves the current token.
    /// - Returns: A `Result` containing a `Token` on success or `OidcError` on failure.
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    /// Refreshes the token.
    /// - Returns: A `Result` containing the refreshed `Token` or `OidcError` on failure.
    func refresh() async -> Result<Token, OidcError> {
        await user.refresh()
    }
    
    /// Revokes the user's token.
    func revoke() async {
        await user.revoke()
    }
    
    /// Retrieves user info.
    /// - Parameter cache: Whether to use cached user info if available.
    /// - Returns: A `Result` containing `UserInfo` or `OidcError`.
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    /// The session value string.
    var value: String {
        get {
            return session.value
        }
    }
}

