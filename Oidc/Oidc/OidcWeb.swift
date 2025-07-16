// 
//  OidcLogin.swift
//  Oidc
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingLogger
import PingBrowser

public typealias OidcWeb = Workflow

public class OidcWebConfig: WorkflowConfig, @unchecked Sendable {
    public var browserType: BrowserType = .authSession
    public var browserMode: BrowserMode = .login
}

public extension OidcWeb {
    static func createOidcLogin(block: @Sendable (OidcWebConfig) -> Void = {_ in }) -> OidcWeb {
        let config = OidcWebConfig()
        config.logger = LogManager.standard
        config.timeout = 30
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: Request.Constants.xRequestedWith, value: Request.Constants.pingSdk)
            customHeaderConfig.header(name: Request.Constants.xRequestedPlatform, value: Request.Constants.ios)
        }
        
        config.module(OidcModule.config)
        // Apply custom configuration
        block(config)
        
        return OidcWeb(config: config)
    }
    
    func authorize() async throws -> Result<User, OidcError> {
        let result = try await startOidcLogin()
        switch result {
        case let failureNode as FailureNode:
            return Result<User, OidcError>.failure(OidcError.unknown(message: failureNode.cause.localizedDescription))
        case let successNode as SuccessNode:
            return Result<User, OidcError>.success(successNode.session as! User)
        default:
            return Result<User, OidcError>.failure(OidcError.unknown(message: "Unexpected result"))
        }
    }
    
    func startOidcLogin() async throws -> Node {
        let request = Request()
        try await initialize()
        config.logger.i("Starting...")
        let context = FlowContext(flowContext: SharedContext())
        var currentRequest = request
        for handler in startHandlers {
            currentRequest = try await handler(context, currentRequest)
        }
        
        let emptySession = EmptySession()
        
        var successNode = SuccessNode(session: emptySession)
        for handler in successHandlers {
            successNode = try await handler(context, successNode)
        }
        
        return successNode
    }
    
    func user() async -> User? {
        try? await initialize()
        
        if let cachedUser = self.sharedContext.get(key: SharedContext.Keys.userKey) as? User {
            return cachedUser
        }
        
        if await hasCookies() {
            if let oidcClientConfig = self.sharedContext.get(key: SharedContext.Keys.oidcClientConfigKey) as? OidcClientConfig {
                return await prepareUser(oidcLogin: self, user: OidcUser(config: oidcClientConfig))
            }
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

struct UserDelegate: User, Session {
    private let oidcLogin: OidcWeb
    private let user: User
    private let session: Session
    
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
    
    func token() async -> Result<Token, OidcError> {
        return await user.token()
    }
    
    func revoke() async {
        await user.revoke()
    }
    
    func userinfo(cache: Bool) async -> Result<UserInfo, OidcError> {
        await user.userinfo(cache: cache)
    }
    
    var value: String {
        get {
            return session.value
        }
    }
}
