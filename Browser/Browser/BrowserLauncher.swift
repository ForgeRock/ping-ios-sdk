//
//  Browser.swift
//  Browser
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
public enum BrowserError: Error, Sendable {
    case externalUserAgentFailure
    case externalUserAgentAuthenticationInProgress
    case externalUserAgentCancelled
}

/// BrowserMode enum to specify the mode of the browser; login, logout, or custom
public enum BrowserMode: Sendable {
    case login
    case logout
    case custom
}

/// A protocol to abstract the BrowserLauncher functionality (if not already provided).
/// (If your project already has a protocol that BrowserLauncher conforms to, you can use it.)

@MainActor
public protocol BrowserLauncherProtocol: Sendable {
    var isInProgress: Bool { get }
    func launch(url: URL, customParams: [String: String]?,
                browserType: BrowserType, browserMode: BrowserMode, callbackURLScheme: String) async throws -> URL
    func reset()
    func handleAppActivation()
}

/// BrowserLauncher class to launch external user-agent for web requests
@MainActor
public final class BrowserLauncher: NSObject, BrowserLauncherProtocol {
    
    private enum State {
        case idle
        case launching
        case authenticating(session: Any)
        case closing
    }
    
    // MARK: Properties
    
    /// Static shared instance of current Browser object
    public static var currentBrowser: BrowserLauncherProtocol = BrowserLauncher()
    
    /// Boolean indicator whether or not current Browser object is in progress
    public var isInProgress: Bool {
        if case .idle = state {
            return false
        }
        return true
    }
    
    /// Custom URL query parameter for /authorize request
    private var customParams: [String: String] = [:]
    
    /// Type of external user-agent; Authentication Service, Native Browser App, or SFSafariViewController
    private var browserType: BrowserType = .authSession
    
    /// Current external user-agent instance
    private var currentSession: Any? {
        if case .authenticating(let session) = state {
            return session
        }
        return nil
    }
    
    /// Browser mode (either login, logout or custom)
    private var browserMode: BrowserMode = .login
    
    /// Continuation to be used by the delegate or the sink
    private var loginContinuation: CheckedContinuation<URL, Error>?
    
    /// Cancellable for Combine subscription
    private var cancellable: AnyCancellable?
    
    /// Logger instance
    var logger: Logger = LogManager.logger
    
    private var state: State = .idle
    
    // MARK: Public Methods
    
    /// Handles app activation event
    /// - Note: If the app becomes active during native browser authentication, the authentication will be cancelled.
    public func handleAppActivation() {
        if case .authenticating(let session) = state, session is String {
            logger.i("App became active during native browser authentication. Cancelling.")
            loginContinuation?.resume(throwing: BrowserError.externalUserAgentCancelled)
            cleanup()
        }
    }
    
    /// Resets the browser state and dismisses any presented view controllers.
    /// - Note: If the browser is not in an authenticating state, this method will log a warning and return without making any changes.
    public func reset() {
        logger.i("Resetting the browser")
        
        guard case .authenticating(let session) = state else {
            logger.w("Browser is not in a state that can be reset.", error: nil)
            return
        }
        
        state = .closing
        
        if let session = session as? SFSafariViewController {
            session.dismiss(animated: false) {
                self.cleanup()
            }
        } else {
            cleanup()
        }
        
        loginContinuation?.resume(throwing: BrowserError.externalUserAgentCancelled)
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
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String) async throws -> URL {
        logger = LogManager.logger
        
        guard case .idle = state else {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        
        state = .launching
        
        var finalUrl = url
        if let params = customParams, !params.isEmpty {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            
            let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            
            if var existingItems = urlComponents?.queryItems {
                existingItems.append(contentsOf: queryItems)
                urlComponents?.queryItems = existingItems
            } else {
                urlComponents?.queryItems = queryItems
            }
            
            if let updatedUrl = urlComponents?.url {
                finalUrl = updatedUrl
            } else {
                logger.i("Failed to append custom parameters to URL, using original URL")
            }
        }
        
        return try await performLaunch(url: finalUrl, browserType: browserType, callbackURLScheme: callbackURLScheme)
    }
    
    // MARK: Private Methods
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func loginWithNativeBrowser(url: URL, callbackURLScheme: String ) async throws -> URL {
        let opened = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                cont.resume(returning: success)
            }
        }
        guard opened else {
            throw BrowserError.externalUserAgentFailure
        }
        
        state = .authenticating(session: "Native Browser")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            
            self.cancellable = OpenURLMonitor.shared.urlPublisher
                .filter { $0.scheme == callbackURLScheme }
                .first()
                .sink { [weak self] url in
                    self?.loginContinuation?.resume(returning: url)
                    self?.cleanup()
                }
        }
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
    private func loginWithSFViewController(url: URL, callbackURLScheme: String ) async throws -> URL {
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.modalPresentationStyle = .fullScreen
        state = .authenticating(session: safariVC)
        
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let presentingVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
            throw BrowserError.externalUserAgentFailure
        }
        
        presentingVC.present(safariVC, animated: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.loginContinuation = continuation
            
            self.cancellable = OpenURLMonitor.shared.urlPublisher
                .filter { $0.scheme == callbackURLScheme }
                .first()
                .sink { [weak self] url in
                    guard let self = self else { return }
                    
                    if case .authenticating(let session) = self.state {
                        self.state = .closing
                        self.loginContinuation?.resume(returning: url)
                        if let sfViewController = session as? SFSafariViewController {
                            sfViewController.dismiss(animated: true) {
                                self.cleanup()
                            }
                        } else {
                            self.cleanup()
                        }
                    }
                }
        }
    }
    
    /// Clean up subscription and reset state
    private func cleanup() {
        cancellable?.cancel()
        cancellable = nil
        loginContinuation = nil
        state = .idle
        logger.i("Browser session cleaned up and state reset.")
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
        return try await withCheckedThrowingContinuation { continuation in
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { [weak self] (url, error) in
                guard let self = self else { return }
                
                self.state = .closing
                
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                }
                self.cleanup()
            }
            
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            self.state = .authenticating(session: authSession)
            
            if !authSession.start() {
                self.state = .closing
                continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                self.cleanup()
            }
        }
    }
    
    /// Closes currently presenting ViewController
    private func close() async {
        guard case .authenticating(let session) = state else {
            return
        }
        
        if let sfViewController = session as? SFSafariViewController {
            self.logger.i("Close called with SFSafariViewController: \(String(describing: self.currentSession))")
            sfViewController.dismiss(animated: true)
        }
        
        if let asAuthSession = session as? ASWebAuthenticationSession {
            self.logger.i("Close called with ASWebAuthenticationSession: \(String(describing: self.currentSession))")
            asAuthSession.cancel()
        }
        
        reset()
    }
}

// MARK: ASWebAuthenticationPresentationContextProviding
extension BrowserLauncher: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: SFSafariViewControllerDelegate
extension BrowserLauncher: SFSafariViewControllerDelegate {
    nonisolated public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor [weak self] in
            self?.logger.i("User cancelled the authorization process by closing the window")
            self?.reset()
        }
    }
    
    nonisolated public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {}
}

/// A singleton that publishes all URLs your app is asked to open.
@MainActor
public final class OpenURLMonitor: NSObject {
    
    /// Shared singleton instance
    public static let shared = OpenURLMonitor()
    
    /// Any subscriber can listen to this to be notified of incoming URLs
    public let urlPublisher = PassthroughSubject<URL, Never>()
    
    private override init() {
        super.init()
    }
    
    /// Call this from your AppDelegate/SceneDelegate when the app is asked to open a URL.
    /// - Returns: You can return the Bool back to the system if you want.
    @discardableResult
    public func handleOpenURL(_ url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        // Broadcast the URL
        urlPublisher.send(url)
        // Return true to indicate you handled it
        return true
    }
}
