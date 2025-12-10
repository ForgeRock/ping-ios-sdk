//
//  CookieModule.swift
//  PingOrchestrate
//
//  Copyright (c) 2024 - 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingStorage

/// A module that manages cookies.
public class CookieModule {
    
    /// Initializes a new instance of `CookieModule`.
    public init() {}
    
    /// The module configuration for managing cookies.
    public static let config: Module<CookieConfig> = Module.of({ CookieConfig() }) {
        setup in
        
        setup.initialize {
            setup.context.set(key: SharedContext.Keys.cookieStorage, value: setup.config.cookieStorage)
        }
        
        setup.start { @Sendable context, request in
            let cookies = try? await setup.config.cookieStorage.get()
            if let url = request.urlRequest.url, let cookies = cookies {
                await CookieModule.inject(url: url,
                                          cookies: cookies,
                                          request: request)
            }
            return request
        }
        
        setup.next { @Sendable context, _, request in
            if let url = request.urlRequest.url {
                let allCookies = await setup.config.inMemoryStorage.cookies(for: url)
                if let allCookies = allCookies {
                    request.cookies(cookies: allCookies)
                }
                // Inject persisted cookies from cookie storage if available
                if let cookies = try? await setup.config.cookieStorage.get() {
                    await CookieModule.inject(url: url, cookies: cookies, request: request)
                }
            }
            return request
        }
        
        setup.response { @Sendable context, response in
            let cookies = response.getCookies()
            if cookies.count > 0, let httpResponse = response as? HttpResponse, let url = httpResponse.response.url {
                await CookieModule.parseResponseForCookie(context: context,
                                                          url: url,
                                                          cookies: cookies,
                                                          storage: setup.config.inMemoryStorage,
                                                          cookieConfig: setup.config)
            }
        }
        
        setup.signOff { @Sendable request in
            if let url = request.urlRequest.url {
                if let cookies = try? await setup.config.cookieStorage.get() {
                    await CookieModule.inject(url: url, cookies: cookies, request: request)
                }
                try? await setup.config.cookieStorage.delete()
                await setup.config.inMemoryStorage.deleteCookies(url: url)
            }
            return request
        }
    }
    
    /// Injects cookies into an HTTP request.
    /// - Parameters:
    ///   - url: The URL of the request.
    ///   - cookies: The cookies to be injected.
    ///   - request: The HTTP request to modify.
    static func inject(url: URL,
                       cookies: [CustomHTTPCookie],
                       request: Request) async {
        
        let persistedTempCookiesStorage = InMemoryCookieStorage()
        let httpCookies = cookies.compactMap { $0.toHTTPCookie() }
        for cookie in httpCookies {
            await persistedTempCookiesStorage.setCookie(cookie)
        }
        
        if let cookie = await persistedTempCookiesStorage.cookies(for: url) {
            request.cookies(cookies: cookie)
        }
    }
    
    /// Parses cookies from an HTTP response and updates storage.
    /// - Parameters:
    ///   - context: The workflow context.
    ///   - url: The URL associated with the response.
    ///   - cookies: The cookies received in the response.
    ///   - storage: In-memory cookie storage.
    ///   - cookieConfig: Configuration for cookie persistence.
    static func parseResponseForCookie(context: FlowContext,
                                       url: URL,
                                       cookies: [HTTPCookie],
                                       storage: InMemoryCookieStorage?,
                                       cookieConfig: CookieConfig) async {
        
        let persistCookies = cookies.filter { cookieConfig.persist.contains($0.name) }
        let otherCookies = cookies.filter { !cookieConfig.persist.contains($0.name) }
        
        if !persistCookies.isEmpty {
            let persistedTempCookiesStorage = InMemoryCookieStorage()
            // Add existing cookies to cookie storage
            if let httpCookies = try? await cookieConfig.cookieStorage.get()?.compactMap({ $0.toHTTPCookie() }) {
                for cookie in httpCookies {
                    await persistedTempCookiesStorage.setCookie(cookie)
                }
            }
            
            // Clear existing cookies from keychain
            try? await cookieConfig.cookieStorage.delete()
            
            // Add new cookies to temp cookie storage
            for cookie in persistCookies {
                await persistedTempCookiesStorage.setCookie(cookie)
            }
            
            // Persist only the required cookies to keychain
            let cookieData = await persistedTempCookiesStorage.cookies(for: url)?
                .filter { cookieConfig.persist.contains($0.name) }
                .compactMap { value in
                    CustomHTTPCookie(from: value)
                }
            if let cookieData = cookieData {
                try? await cookieConfig.cookieStorage.save(item: cookieData)
            }
            
        }
        
        // Persist non-persist cookies to cookie storage
        for cookie in otherCookies {
            await storage?.setCookie(cookie)
        }
    }
}


/// Configuration for managing cookies in the application.
///
/// `CookieConfig` provides control over how HTTP cookies are stored, persisted,
/// and managed across requests in your Journey or DaVinci workflows. It supports
/// both in-memory storage (for temporary cookies) and persistent storage (for
/// cookies that should survive app restarts).
///
/// ## Cookie Persistence
///
/// By default, cookies are stored in memory only. To persist specific cookies
/// to Keychain storage, add their names to the ``persist`` array:
///
/// ```swift
/// let cookieConfig = CookieConfig()
/// cookieConfig.persist = ["iPlanetDirectoryPro", "session_token"]
/// ```
///
/// Only cookies whose names appear in the ``persist`` array will be saved to
/// the Keychain. All other cookies remain in memory only and are cleared when
/// the app terminates.
///
/// ## Custom Storage Configuration
///
/// For multi-user scenarios or apps requiring isolated cookie storage, use the
/// custom account initializer:
///
/// ```swift
/// // User-specific cookie storage
/// let userCookieConfig = CookieConfig(account: "user_12345_cookies")
///
/// // Another user with separate storage
/// let adminCookieConfig = CookieConfig(account: "admin_cookies")
/// ```
///
/// ## Integration with Modules
///
/// `CookieConfig` is typically used with ``CookieModule`` in Journey workflows:
///
/// ```swift
/// let journey = Journey.createJourney { config in
///     config.module(CookieModule.config) { cookieConfig in
///         cookieConfig.persist = ["iPlanetDirectoryPro"]
///         // Cookies will be persisted to default Keychain storage
///     }
/// }
/// ```
///
/// - Note: This class is marked as `@unchecked Sendable` because its properties
///   are mutable but access is coordinated through the Journey module system.
///
/// - SeeAlso: ``CookieModule`` for the module that uses this configuration
/// - SeeAlso: ``CustomHTTPCookie`` for the cookie type used in persistent storage
public final class CookieConfig: @unchecked Sendable {
    typealias Cookies = [String]
    
    /// A list of cookie names that should be persisted to secure storage.
    ///
    /// Only cookies whose names appear in this array will be saved to the
    /// Keychain when received from the server. Cookies not in this list are
    /// stored in memory only and will be lost when the app terminates.
    ///
    /// ## Common Cookies to Persist
    ///
    /// Authentication cookies that maintain session state across app launches
    /// should be added to this array:
    ///
    /// ```swift
    /// cookieConfig.persist = [
    ///     "iPlanetDirectoryPro",  // ForgeRock/PingAM session cookie
    ///     "session_token",         // Custom session cookie
    ///     "remember_me"            // Persistent login cookie
    /// ]
    /// ```
    ///
    /// ## Default Behavior
    ///
    /// By default, this array is empty (`[]`), meaning no cookies are persisted.
    /// All cookies are stored in memory only.
    ///
    /// - Important: Only include cookie names that are required for maintaining
    ///   authentication state. Persisting unnecessary cookies can impact storage
    ///   size and may have privacy implications.
    public var persist: [String] = []
    
    /// In-memory storage for cookies that are not persisted.
    ///
    /// This actor-based storage manages cookies that should only exist for the
    /// current app session. Cookies in this storage are automatically cleared
    /// when the app terminates.
    ///
    /// The storage is used for:
    /// - Cookies not listed in ``persist``
    /// - Temporary cookies received during authentication flows
    /// - Session-only cookies
    ///
    /// - Note: This property is read-only. The storage is initialized automatically
    ///   and managed by the ``CookieModule``.
    public private(set) var inMemoryStorage: InMemoryCookieStorage
    
    /// Persistent storage for cookies listed in the ``persist`` array.
    ///
    /// This storage backend (typically Keychain) maintains cookies across app
    /// launches. Only cookies whose names appear in ``persist`` are saved here.
    ///
    /// ## Default Storage
    ///
    /// By default, uses `KeychainStorage` with:
    /// - Account identifier: `"COOKIE_STORAGE"`
    /// - Encryption: Secured key encryption when available
    ///
    /// ## Custom Storage
    ///
    /// You can replace this with custom storage implementations:
    ///
    /// ```swift
    /// cookieConfig.cookieStorage = KeychainStorage<[CustomHTTPCookie]>(
    ///     account: "my_custom_cookies",
    ///     encryptor: SecuredKeyEncryptor() ?? NoEncryptor()
    /// )
    /// ```
    ///
    /// - SeeAlso: ``CustomHTTPCookie`` for the cookie type stored persistently
    public var cookieStorage: StorageDelegate<[CustomHTTPCookie]>
    
    /// Initializes a new `CookieConfig` with default Keychain storage.
    ///
    /// This creates a cookie configuration using:
    /// - Empty ``persist`` array (no cookies persisted by default)
    /// - Default Keychain account identifier (`"COOKIE_STORAGE"`)
    /// - Secured key encryption for persistent storage
    /// - Fresh in-memory storage instance
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cookieConfig = CookieConfig()
    /// cookieConfig.persist = ["iPlanetDirectoryPro"]
    ///
    /// // Use in a Journey module
    /// config.module(CookieModule.config) { cookie in
    ///     cookie.persist = cookieConfig.persist
    /// }
    /// ```
    ///
    /// - SeeAlso: `init(account:)` for custom storage accounts
    public init() {
        cookieStorage = KeychainStorage<[CustomHTTPCookie]>(account: SharedContext.Keys.cookieStorage, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
        inMemoryStorage = InMemoryCookieStorage()
    }
    
    /// Initializes a new `CookieConfig` with a custom account identifier for Keychain storage.
    ///
    /// Use this initializer when you need to isolate cookie storage with a unique
    /// identifier. This is particularly useful for:
    /// - Multi-user applications where each user needs separate cookie storage
    /// - Multiple DaVinci workflow instances requiring isolated state
    /// - Testing scenarios requiring clean storage separation
    ///
    /// The account identifier serves as the Keychain account attribute, allowing
    /// multiple cookie stores to coexist without conflicts.
    ///
    /// ## Example: Multi-User Cookie Storage
    ///
    /// ```swift
    /// // Create cookie config for a specific user
    /// let userCookieConfig = CookieConfig(account: "user_12345_cookies")
    /// userCookieConfig.persist = ["iPlanetDirectoryPro"]
    ///
    /// // Use in Journey configuration
    /// let journey = Journey.createJourney { config in
    ///     config.module(CookieModule.config) { cookie in
    ///         cookie.cookieStorage = userCookieConfig.cookieStorage
    ///         cookie.persist = userCookieConfig.persist
    ///     }
    /// }
    /// ```
    ///
    /// ## Example: Isolated Workflow Storage
    ///
    /// ```swift
    /// // Different workflows with separate cookie storage
    /// let loginCookies = CookieConfig(account: "login_flow_cookies")
    /// let checkoutCookies = CookieConfig(account: "checkout_flow_cookies")
    /// ```
    ///
    /// - Parameter account: A unique identifier for this cookie storage instance.
    ///   This value is used as the Keychain account attribute. Choose a descriptive
    ///   and unique value to avoid conflicts with other storage instances.
    ///
    /// - Important: Ensure account identifiers are unique across your app to prevent
    ///   unintended cookie data sharing between different users or workflow contexts.
    ///
    /// - SeeAlso: `init()` for the default configuration
    public convenience init(account: String) {
        self.init()
        cookieStorage = KeychainStorage<[CustomHTTPCookie]>(account: account, encryptor: SecuredKeyEncryptor() ?? NoEncryptor())
    }
}


extension Workflow {
    /// Checks if the workflow has cookies available in storage.
    /// - Returns: A Boolean value indicating whether cookies exist in the storage.
    public func hasCookies() async -> Bool {
        let storage = sharedContext.get(key: SharedContext.Keys.cookieStorage) as? StorageDelegate<[CustomHTTPCookie]>
        let value = try? await storage?.get()
        return (value != nil) && (value?.count ?? 0 > 0)
    }
}

/// A storage class for managing in-memory cookies.
public final actor InMemoryCookieStorage {
    private var cookieStore: [HTTPCookie] = []
    
    /// Adds or updates a cookie in the storage.
    /// - Parameter cookie: The cookie to add or update.
    public func setCookie(_ cookie: HTTPCookie) {
        cookieStore.removeAll { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }
        cookieStore.append(cookie)
    }
    
    /// Deletes a specific cookie from the storage.
    /// - Parameter cookie: The cookie to delete.
    public func deleteCookie(_ cookie: HTTPCookie) {
        cookieStore.removeAll { $0 == cookie }
    }
    
    /// Deletes all cookies associated with a specific URL.
    /// - Parameter url: The URL whose cookies should be deleted.
    public func deleteCookies(url: URL) {
        cookies(for: url)?.forEach { value in
            deleteCookie(value)
        }
    }
    
    /// Retrieves all cookies currently stored.
    public var cookies: [HTTPCookie]? {
        return cookieStore
    }
    
    /// Retrieves cookies associated with a specific URL.
    /// - Parameter url: The URL to fetch cookies for.
    public func cookies(for url: URL) -> [HTTPCookie]? {
        return cookieStore.filter {!$0.isExpired && $0.validateURL(url)  }
    }
    
    /// Adds multiple cookies to the storage.
    /// - Parameters:
    ///   - cookies: The cookies to add.
    ///   - url: The URL associated with the cookies (optional).
    ///   - mainDocumentURL: The main document URL (optional).
    public func setCookies(_ cookies: [HTTPCookie], for url: URL?, mainDocumentURL: URL?) {
        for cookie in cookies {
            setCookie(cookie)
        }
    }
}


extension SharedContext.Keys {
    static let cookieStorage = "COOKIE_STORAGE"
}


extension HTTPCookie {
    var isExpired: Bool {
        get {
            if let expDate = self.expiresDate, expDate.timeIntervalSince1970 < Date().timeIntervalSince1970 {
                return true
            }
            return false
        }
    }
    
    func validateIsSecure(_ url: URL) -> Bool {
        if !self.isSecure {
            return true
        }
        if let urlScheme = url.scheme, urlScheme.lowercased() == "https" {
            return true
        }
        return false
    }
    
    func validateURL(_ url: URL) -> Bool {
        return self.validateDomain(url: url) && self.validatePath(url: url)
    }
    
    private func validatePath(url: URL) -> Bool {
        let path = url.path.count == 0 ? "/" : url.path
        
        //  For exact matching i.e. /path == /path
        if path == self.path {
            return true
        }
        
        //  For partial matching
        if path.hasPrefix(self.path) {
            //  if Cookie path ends with /
            //  i.e. /abc == / or /abc/def == /abc/
            if self.path.hasSuffix("/") {
                return true
            }
            
            //  making sure to validate exact path matching
            //  i.e. /abcd != /abc, /abc/def == /abc
            if path.hasPrefix(self.path + "/") {
                return true
            }
        }
        return false
    }
    
    private func validateDomain(url: URL) -> Bool {
        
        guard let host = url.host else {
            //  Invalid URL host
            return false
        }
        
        //  For exact matching i.e. forgerock.com == forgerock.com or am.forgerock.com == am.forgerock.com
        if host == self.domain {
            return true
        }
        //  For sub domain matching i.e. demo.forgerock.com == .forgerock.com
        if host.hasSuffix(self.domain) {
            return true
        }
        //  For ignoring leading dot
        if (self.domain.count - host.count == 1) && self.domain.hasPrefix(".") {
            return true
        }
        return false
    }
}
