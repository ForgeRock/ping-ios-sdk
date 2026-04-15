//
//  Browser.swift
//  Browser
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices
import PingLogger
import SafariServices
import Combine
import UIKit

// MARK: - Enums
/// BrowserType enum to specify the type of external user-agent;
/// ASWebAuthenticationSession, Native Browser App,  SFSafariViewController,
/// or ASWebAuthenticationSession with prefersEphemeralWebBrowserSession set to true
public enum BrowserType: Int, Sendable {
    case authSession = 0
    case nativeBrowserApp = 1
    case sfViewController = 2
    case ephemeralAuthSession = 3
}

/// BrowserError enum to specify the error that may occur during external user-agent process
public enum BrowserError: Error, LocalizedError, Sendable {
    case externalUserAgentFailure
    case externalUserAgentAuthenticationInProgress
    case externalUserAgentCancelled

    public var errorDescription: String? {
        switch self {
        case .externalUserAgentFailure:
            return "The external user agent failed to launch or complete authentication."
        case .externalUserAgentAuthenticationInProgress:
            return "An authentication session is already in progress."
        case .externalUserAgentCancelled:
            return "The authentication was cancelled by the user."
        }
    }
}

/// BrowserMode enum to specify the mode of the browser
public enum BrowserMode: Sendable {
    case login
    case logout
    case custom
}

// MARK: - Protocol
/// A protocol to abstract the BrowserLauncher functionality (if not already provided).
/// (If your project already has a protocol that BrowserLauncher conforms to, you can use it.)
@MainActor
public protocol BrowserLauncherProtocol: Sendable {
    var isInProgress: Bool { get }
    func launch(url: URL, customParams: [String: String]?,
                browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String, logger: Logger) async throws -> URL
    func reset()
    func handleAppActivation()
}

// MARK: - BrowserLauncher

/// BrowserLauncher class to launch external user-agent for web requests
@MainActor
public final class BrowserLauncher: NSObject, BrowserLauncherProtocol {
    
    // MARK: Internal State
    private enum State {
        case idle
        case launching
        case authenticating(session: Any) // Holds ASWebAuthenticationSession or SFSafariViewController
        case closing
    }
    
    // MARK: Properties
    
    /// Static shared instance
    public static var currentBrowser: BrowserLauncherProtocol = BrowserLauncher()
    
    public var isInProgress: Bool {
        if case .idle = state { return false }
        return true
    }
    
    private var state: State = .idle
    private var browserType: BrowserType = .authSession
    private var browserMode: BrowserMode = .login
    private var logger: Logger = LogManager.logger
    
    // Concurrency & Combine
    private var loginContinuation: CheckedContinuation<URL, Error>?
    private var cancellable: AnyCancellable?
    
    // MARK: - Public Methods
    
    /// Handles app activation event
    public func handleAppActivation() {
        // If we are using the Native Browser (jumping out of app), and the app comes back
        // to foreground without a URL callback, we assume the user cancelled/switched back manually.
        if case .authenticating(let session) = state, session is String { // "String" marker used for Native Browser
            logger.i("App became active during native browser authentication. Cancelling.")
            reset()
        }
    }
    
    /// Resets the browser state, cancels continuations, and dismisses controllers.
    public func reset() {
        logger.i("Resetting the browser. Current state: \(state)")
        
        guard case .authenticating(let session) = state else {
            // If we are launching or closing, we still might need to clean up continuation
            if loginContinuation != nil {
                forceCancelContinuation()
                cleanup()
            } else {
                logger.w("Browser is not in a state that requires reset.", error: nil)
            }
            return
        }
        
        state = .closing
        
        // 1. Capture and Nil the continuation to prevent double-resume
        let pendingContinuation = self.loginContinuation
        self.loginContinuation = nil
        
        // 2. Resume with cancellation error immediately
        pendingContinuation?.resume(throwing: BrowserError.externalUserAgentCancelled)
        
        // 3. Handle Session Cleanup
        if let sfViewController = session as? SFSafariViewController {
            logger.i("Dismissing SFSafariViewController")
            sfViewController.dismiss(animated: false) { [weak self] in
                self?.cleanup()
            }
        } else if let asAuthSession = session as? ASWebAuthenticationSession {
            logger.i("Cancelling ASWebAuthenticationSession")
            // This triggers the completion handler, but we nilled the continuation above, so it's safe.
            asAuthSession.cancel()
            cleanup()
        } else {
            // Native browser or unknown
            logger.i("Resetting non-UI session")
            cleanup()
        }
    }
    
    /// Launches external user-agent for web requests
    /// - Parameters:
    ///   - url: URL to follow for the external user-agent
    ///   - customParams: Any custom URL query parameters to be passed as URL parameters in the request
    ///   - browserType: BrowserType enum to specify the type of external user-agent
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom
    ///   - callbackURLScheme: The callbackURLScheme to be used for returning to the app. Used in ASWebAuthenticationSession modes
    ///   - Returns: URL of the external user-agent
    ///   - Throws: BrowserError
    public func launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String, logger: Logger = LogManager.logger) async throws -> URL {
        self.logger = logger
        
        guard case .idle = state else {
            logger.e("Attempted to launch browser while another session is in progress", error: nil)
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        
        state = .launching
        self.browserType = browserType
        self.browserMode = browserMode
        
        // Prepare URL
        let finalUrl = appendCustomParams(to: url, params: customParams)
        
        logger.i("Launching browser type: \(browserType) for URL: \(finalUrl.absoluteString)")
        
        return try await performLaunch(url: finalUrl, browserType: browserType, callbackURLScheme: callbackURLScheme)
    }
    
    // MARK: - Private Helpers
    
    private func appendCustomParams(to url: URL, params: [String: String]?) -> URL {
        guard let params = params, !params.isEmpty else { return url }
        
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        if var existingItems = urlComponents?.queryItems {
            existingItems.append(contentsOf: queryItems)
            urlComponents?.queryItems = existingItems
        } else {
            urlComponents?.queryItems = queryItems
        }
        
        return urlComponents?.url ?? url
    }
    
    /// Performs the launch based on the specified browser type
    /// - Parameters:
    ///  - url: The URL to be opened
    ///  - browserType: The type of browser to be used
    ///  - callbackURLScheme: The callback URL scheme for the app
    ///  - Returns: The URL after authentication is complete
    ///  - Throws: An error if the launch fails
    private func performLaunch(url: URL, browserType: BrowserType, callbackURLScheme: String) async throws -> URL {
        switch browserType {
        case .nativeBrowserApp:
            return try await loginWithNativeBrowser(url: url, callbackURLScheme: callbackURLScheme)
        case .sfViewController:
            return try await loginWithSFViewController(url: url, callbackURLScheme: callbackURLScheme)
        case .authSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: false)
        case .ephemeralAuthSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: true)
        }
    }
    
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func forceCancelContinuation() {
        if let continuation = loginContinuation {
            continuation.resume(throwing: BrowserError.externalUserAgentCancelled)
            loginContinuation = nil
        }
    }
    
    // Cleans up the cancelables and continuations
    private func cleanup() {
        cancellable?.cancel()
        cancellable = nil
        loginContinuation = nil // Ensure nil
        state = .idle
        logger.i("Browser session cleaned up.")
    }
    
    // MARK: - Specific Browser Implementations
    
    /// Performs authentication through /authorize endpoint using Native Browser
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func loginWithNativeBrowser(url: URL, callbackURLScheme: String) async throws -> URL {
        let opened = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                cont.resume(returning: success)
            }
        }
        
        guard opened else {
            state = .idle
            throw BrowserError.externalUserAgentFailure
        }
        
        state = .authenticating(session: "Native Browser")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            self.observeCallback(scheme: callbackURLScheme)
        }
    }
    
    /// Performs authentication through /authorize endpoint using SFViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func loginWithSFViewController(url: URL, callbackURLScheme: String) async throws -> URL {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.modalPresentationStyle = .fullScreen
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let presentingVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
            state = .idle
            throw BrowserError.externalUserAgentFailure
        }
        
        // We set state BEFORE presenting to prevent race conditions
        state = .authenticating(session: safariVC)
        presentingVC.present(safariVC, animated: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            
            // For SFVC, we also listen for the URL callback via the Monitor
            self.cancellable = OpenURLMonitor.shared.urlPublisher
                .filter { $0.scheme == callbackURLScheme }
                .first()
                .sink { [weak self] url in
                    guard let self = self else { return }
                    
                    // SFVC flow successful
                    if let activeContinuation = self.loginContinuation {
                        activeContinuation.resume(returning: url)
                        self.loginContinuation = nil // Consumed
                    }
                    
                    self.state = .closing
                    
                    // Close the UI
                    safariVC.dismiss(animated: true) { [weak self] in
                        self?.cleanup()
                    }
                }
        }
    }
    
    /// Performs authentication through /authorize endpoint using ASWebAuthenticationSession
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - callbackURLScheme: Callback URL Scheme to return to the app
    ///   - prefersEphemeralWebBrowserSession: Set to true to use ephemeral web browser session
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if authentication fails
    private func asWebAuthenticationSession(url: URL, callbackURLScheme: String,
                                            prefersEphemeralWebBrowserSession: Bool) async throws -> URL {
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                return
            }
            
            self.loginContinuation = continuation
            
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { [weak self] (callbackURL, error) in
                guard let self = self else { return }
                
                self.logger.i("ASWebAuthenticationSession callback received")
                
                // CRITICAL: Check if continuation is still valid (not nilled by reset())
                guard let activeContinuation = self.loginContinuation else {
                    self.logger.i("Continuation already consumed or cancelled. Ignoring Session callback.")
                    return
                }
                
                self.loginContinuation = nil // Consume it
                self.state = .closing
                
                if let error = error {
                    // Check for User Cancel
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        activeContinuation.resume(throwing: BrowserError.externalUserAgentCancelled)
                    } else {
                        activeContinuation.resume(throwing: error)
                    }
                } else if let url = callbackURL {
                    activeContinuation.resume(returning: url)
                } else {
                    activeContinuation.resume(throwing: BrowserError.externalUserAgentFailure)
                }
                
                self.cleanup()
            }
            
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            
            self.state = .authenticating(session: authSession)
            
            if !authSession.start() {
                self.logger.e("Failed to start ASWebAuthenticationSession", error: nil)
                self.state = .closing
                // Resume immediately on failure
                self.loginContinuation?.resume(throwing: BrowserError.externalUserAgentFailure)
                self.loginContinuation = nil
                self.cleanup()
            }
        }
    }
    
    private func observeCallback(scheme: String) {
        // Used for Native Browser mode
        self.cancellable = OpenURLMonitor.shared.urlPublisher
            .filter { $0.scheme == scheme }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self = self, let continuation = self.loginContinuation else { return }
                continuation.resume(returning: url)
                self.loginContinuation = nil
                self.cleanup()
            }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension BrowserLauncher: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Fix: Return the actual window, not a new instance
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        return window ?? ASPresentationAnchor()
    }
}

// MARK: - SFSafariViewControllerDelegate

extension BrowserLauncher: SFSafariViewControllerDelegate {
    nonisolated public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor [weak self] in
            self?.logger.i("User cancelled SFSafariViewController by closing the window")
            self?.reset()
        }
    }
    
    nonisolated public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {}
}

// MARK: - OpenURLMonitor

/// A singleton that publishes all URLs your app is asked to open.
@MainActor
public final class OpenURLMonitor: NSObject {
    
    public static let shared = OpenURLMonitor()
    
    public let urlPublisher = PassthroughSubject<URL, Never>()
    
    private override init() {
        super.init()
    }
    
    @discardableResult
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        urlPublisher.send(url)
        return true
    }
}
