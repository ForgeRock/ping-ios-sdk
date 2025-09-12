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
}

/// BrowserLauncher class to launch external user-agent for web requests
@MainActor
public final class BrowserLauncher: NSObject, BrowserLauncherProtocol {
    
    // MARK: Properties
    
    /// Static shared instance of current Browser object
    public static var currentBrowser: BrowserLauncherProtocol = BrowserLauncher()
    
    /// Boolean indicator whether or not current Browser object is in progress
    private(set) public var isInProgress: Bool = false
    
    /// Custom URL query parameter for /authorize request
    private var customParams: [String: String] = [:]
    
    /// Type of external user-agent; Authentication Service, Native Browser App, or SFSafariViewController
    private var browserType: BrowserType = .authSession
    
    /// Current external user-agent instance
    private var currentSession: Any?
    
    /// Browser mode (either login, logout or custom)
    private var browserMode: BrowserMode = .login
    
    /// Continuation to be used by the delegate or the sink
    private var loginContinuation: CheckedContinuation<URL, Error>?
    
    /// Cancellable for Combine subscription
    private var cancellable: AnyCancellable?
    
    /// Logger instance
    var logger: Logger = LogManager.logger {
        didSet {
            // Propagate the logger to Modules
            LogManager.logger = logger
        }
    }
    
    // MARK: Public Methods
    
    /// Resets the browser state
    public func reset() {
        self.logger.i("Resetting the browser")
        if let session = self.currentSession as? SFSafariViewController {
            session.dismiss(animated: false)
        }
        
        if self.isInProgress {
            self.loginContinuation?.resume(throwing: BrowserError.externalUserAgentCancelled)
        }
        
        self.cleanup()
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
        
        // Make sure that no Browser instance is currently running
        if BrowserLauncher.currentBrowser.isInProgress {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        
        self.isInProgress = true
        
        // If we have custom parameters, add them to the URL
        var finalUrl = url
        if let params = customParams, !params.isEmpty {
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            
            // Create query items from custom parameters
            let queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            
            // If URL already has query items, append to them, otherwise set them
            if var existingItems = urlComponents?.queryItems {
                existingItems.append(contentsOf: queryItems)
                urlComponents?.queryItems = existingItems
            } else {
                urlComponents?.queryItems = queryItems
            }
            
            // Get the final URL with parameters
            if let updatedUrl = urlComponents?.url {
                finalUrl = updatedUrl
            } else {
                logger.i("Failed to append custom parameters to URL, using original URL")
            }
        }
        
        // Launch the browser based on type
        switch browserType {
        case .nativeBrowserApp:
            return try await loginWithNativeBrowser(url: finalUrl, callbackURLScheme: callbackURLScheme)
            
        case .sfViewController:
            return try await loginWithSFViewController(url: finalUrl, callbackURLScheme: callbackURLScheme)
            
        case .authSession:
            return try await asWebAuthenticationSession(url: finalUrl, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: false)
            
        case .ephemeralAuthSession:
            return try await asWebAuthenticationSession(url: finalUrl, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: true)
        }
    }
    
    // MARK: Private Methods
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func loginWithNativeBrowser(url: URL, callbackURLScheme: String ) async throws -> URL {
        // 1. Open in external browser
        let opened = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            UIApplication.shared.open(url, options: [:]) { success in
                cont.resume(returning: success)
            }
        }
        guard opened else {
            cleanup()
            throw BrowserError.externalUserAgentFailure
        }
        
        // 2. Await the result using the class-level continuation
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
    
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func loginWithSFViewController(url: URL, callbackURLScheme: String ) async throws -> URL {
       guard self.loginContinuation == nil else {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        // 1. Prepare and present the Safari VC
        let safariVC = SFSafariViewController(url: url)
        safariVC.delegate = self
        safariVC.modalPresentationStyle = .fullScreen
        self.currentSession = safariVC
        
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let presentingVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
            throw BrowserError.externalUserAgentFailure
        }
        
        presentingVC.present(safariVC, animated: true)
        
        // 2. Await the result using the continuation stored in a property
        return try await withCheckedThrowingContinuation { continuation in
            // STORE the continuation to be used by the delegate or the sink
            self.loginContinuation = continuation
            
            // Listen for the incoming URL
            self.cancellable = OpenURLMonitor.shared.urlPublisher
                .filter { $0.scheme == callbackURLScheme }
                .first()
                .sink { [weak self] url in
                    guard let self = self else { return }

                    // First, resume the continuation to unblock the caller.
                    self.loginContinuation?.resume(returning: url)

                    // Then, dismiss the view controller and clean up the state.
                    if let sfViewController = self.currentSession as? SFSafariViewController {
                        // Set delegate to nil to prevent safariViewControllerDidFinish from firing.
                        sfViewController.delegate = nil
                        sfViewController.dismiss(animated: true) {
                            self.cleanup()
                        }
                    } else {
                        // If there's no view controller, just clean up.
                        self.cleanup()
                    }
                }
        }
    }
    
    /// Clean up subscription and reset state
    private func cleanup() {
        cancellable?.cancel()
        cancellable = nil
        loginContinuation = nil
        currentSession = nil
        isInProgress = false
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
            let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { (url, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                }
            }
            
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            self.currentSession = authSession
            
            if !authSession.start() {
                continuation.resume(throwing: BrowserError.externalUserAgentFailure)
            }
            reset()
        }
    }
    
    /// Closes currently presenting ViewController
    private func close() async {
        if let sfViewController = self.currentSession as? SFSafariViewController {
            self.logger.i("Close called with SFSafariViewController: \(String(describing: self.currentSession))")
            sfViewController.dismiss(animated: true)
        }
        
        if let asAuthSession = self.currentSession as? ASWebAuthenticationSession {
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
