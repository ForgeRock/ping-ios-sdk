// 
//  OidcLogin.swift
//  Oidc
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//



import PingOrchestrate
import PingLogger
import PingBrowser

public typealias OidcWeb = Workflow

/// OidcWeb is a subclass of Workflow
/// - Parameters:
///   - config: The configuration for the OIDC workflow.
///   - Returns: An instance of OidcWeb configured for OIDC login.
public class OidcWebConfig: WorkflowConfig, @unchecked Sendable {
    /// Browser type used for OIDC login.
    public var browserType: BrowserType = .authSession
    /// The mode of the browser for OIDC login.
    public var browserMode: BrowserMode = .login
}

/// OidcOptions is a struct that holds additional parameters for OIDC login.
public struct OidcOptions: Sendable {
    /// Additional parameters for OIDC login.
    public var additionalParameters: [String: String] = [:]
}

public extension OidcWeb {
    /// Creates an OIDC login instance with the provided configuration block.
    /// - Parameter block: A closure to configure the OIDC options.
    /// - Returns: An instance of OidcWeb configured for OIDC login.
    static func createOidcWeb(block: @Sendable (OidcWebConfig) -> Void = {_ in }) -> OidcWeb {
        let config = OidcWebConfig()
        config.timeout = 30
        
        config.module(OidcModule.config)
        config.module(WebModule.config)
        // Apply custom configuration
        block(config)
        
        return OidcWeb(config: config)
    }
    
    /// This method initializes the OIDC client and starts the login process.
    /// - Parameter configure: A closure to configure the OIDC options.
    /// - Returns: A Result containing the User or an OidcError.
    func authorize(configure: @Sendable (inout OidcOptions) -> Void = { _ in }) async throws -> Result<User, OidcError> {
        var options = OidcOptions()
        configure(&options)
        let result = try await startOidcLogin(options: options)
        switch result {
        case let failureNode as FailureNode:
            return Result<User, OidcError>.failure(OidcError.unknown(message: failureNode.cause.localizedDescription))
        case let successNode as SuccessNode:
            guard let user = successNode.session as? User else {
                // This should never happen, but just in case
                return Result<User, OidcError>.failure(OidcError.unknown(message: "Unexpected result: Failed to get User"))
            }
            return Result<User, OidcError>.success(user)
        default:
            return Result<User, OidcError>.failure(OidcError.unknown(message: "Unexpected result"))
        }
    }
    
    /// Starts the OIDC login process.
    /// - Parameter options: The OIDC options containing additional parameters.
    /// - Returns: A Node representing the result of the login process.
    internal func startOidcLogin(options: OidcOptions) async throws -> Node {
        let request = Request()
        try await initialize()
        config.logger.i("Starting...")
        let currentRequest = request
        self.sharedContext.set(key: SharedContext.Keys.oidcParameters, value: options.additionalParameters)
        
        return await self.start(currentRequest)
    }
    
    /// Method to return the OIDC user.
    /// This method checks if the OIDC client is initialized and sets up the necessary configurations.
    /// - Returns: The user if found, otherwise nil.
    func user() async -> User? {
        try? await initialize()
        
        if let cachedUser = self.sharedContext.get(key: SharedContext.Keys.userKey) as? User {
            return cachedUser
        }
        
        if let oidcClientConfig = self.sharedContext.get(key: SharedContext.Keys.oidcClientConfigKey) as? OidcClientConfig {
            return await prepareUser(oidcLogin: self, user: OidcUser(config: oidcClientConfig))
        }
        
        return nil
    }
    
    /// Alias for the Browser.user() method.
    /// - Returns: The user if found, otherwise nil.
    func oidcLoginUser() async -> User? {
        return await user()
    }

    /// Method to prepare the user.
    /// This Method creates a new UserDelegate instance and caches it in the context.
    /// - Parameters:
    ///   - oidcLogin: The OidcLogin instance.
    ///   - user: The user.
    ///   - session: The session.
    /// - Returns: The prepared user.
    internal func prepareUser(
        oidcLogin: OidcWeb,
        user: User,
        session: Session = EmptySession()
    ) async -> UserDelegate {
        let userDelegate = UserDelegate(oidcLogin: oidcLogin, user: user, session: session)
        // Cache the user in the context
        self.sharedContext.set(key: SharedContext.Keys.userKey, value: userDelegate)
        return userDelegate
    }
}

/// UserDelegate is a struct that conforms to User and Session protocols.
/// It is used to manage user sessions and provide methods for user-related operations.
/// - Parameters:
///   - oidcLogin: The OidcWeb instance.
///   - user: The User instance.
///   - session: The Session instance
struct UserDelegate: User, Session, Sendable {
    private let oidcLogin: OidcWeb
    private let user: User
    private let session: Session
    
    /// Initializes a new UserDelegate instance.
    /// - Parameters:
    ///  - oidcLogin: The OidcWeb instance.
    ///  - user: The User instance.
    ///  - session: The Session instance.
    init(oidcLogin: OidcWeb, user: User, session: Session) {
        self.oidcLogin = oidcLogin
        self.user = user
        self.session = session
    }
    
    /// Method to log out the user.
    /// This method removes the cached user from the context and signs off the user.
    func logout() async {
        // remove the cached user from the context
        _ = oidcLogin.sharedContext.removeValue(forKey: SharedContext.Keys.userKey)
        // instead of calling `OidcClient.endSession` directly, we call `DaVinci.signOff` to sign off the user
        _ = await oidcLogin.signOff()
    }
    
    /// Method to get the user Token
    /// - Returns: A Result containing the Token or an OidcError.
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    /// Method to refresh the user token.
    /// - Returns: A Result containing the refreshed Token or an OidcError.
    func refresh() async -> Result<Token, OidcError> {
        await user.refresh()
    }
    
    /// Method to revoke the user token.
    func revoke() async {
        await user.revoke()
    }
    
    /// Method to get the user info.
    /// - Parameter cache: A Boolean indicating whether to use cached user info.
    /// - Returns: A Result containing the UserInfo or an OidcError.
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    /// Method to get the session value.
    /// - Returns: The session value as a String.
    var value: String {
        get {
            return session.value
        }
    }
}
