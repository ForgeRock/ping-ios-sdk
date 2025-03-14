//
//  Browser.swift
//  Browser
//
//  Copyright (c) 2025 Ping Identity. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import AuthenticationServices
import PingLogger
import SafariServices

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
    func launch(url: URL, browserType: BrowserType, callbackURLScheme: String) async throws -> URL
    func reset() async
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
    
    /// Logger instance
    var logger: Logger = LogManager.logger {
        didSet {
            // Propagate the logger to Modules
            LogManager.logger = logger
        }
    }
    
    // MARK: Public Methods
    
    /// Resets the browser state
    public func reset() async {
        // Reset the browser
        self.isInProgress = false
        self.currentSession = nil
    }
    
    /// Launches external user-agent for web requests
    /// - Parameters:
    ///  - url: URL to follow for the external user-agent
    ///  - browserType: BrowserType enum to specify the type of external user-agent
    ///  - callbackURLScheme: The callbackURLScheme to be used for returning to the app. Used in ASWebAuthenticationSession modes
    ///  - Returns: URL of the external user-agent
    public func launch(url: URL, browserType: BrowserType, callbackURLScheme: String) async throws -> URL {
        return try await launch(url: url, browserType: browserType, browserMode: .login, callbackURLScheme: callbackURLScheme)
    }
    
    /// Launches external user-agent for web requests
    /// - Parameters:
    ///   - url: URL to follow for the external user-agent
    ///   - customParams: Any custom URL query parameters to be passed as URL parametes in the request
    ///   - browserType: BrowserType enum to specify the type of external user-agent
    ///   - browserMode: BrowserMode enum to specify the mode of the browser; login, logout, or custom
    ///   - callbackURLScheme: The callbackURLScheme to be used for returning to the app. Used in ASWebAuthenticationSession modes
    ///   - Returns: URL of the external user-agent
    ///   - Throws: BrowserError
    public func launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String) async throws -> URL {
        
        // Make sure that no Browser instance is currently running
        if let currentBrowser = BrowserLauncher.currentBrowser as? BrowserLauncher,
           currentBrowser.isInProgress {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        
        self.isInProgress = true
        
        // Launch the browser based on type
        switch browserType {
        case .nativeBrowserApp:
            guard await UIApplication.shared.open(url) else {
                await reset()
                throw BrowserError.externalUserAgentFailure
            }
            logger.i("BrowserLauncher: Native Browser launched successfully")
            return url
            
        case .sfViewController:
            return try await loginWithSFViewController(url: url)
            
        case .authSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: false)
            
        case .ephemeralAuthSession:
            return try await asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: true)
        }
    }
    
    // MARK: Private Methods
    
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    /// - Returns: URL after authentication is complete
    /// - Throws: BrowserError if the view controller cannot be presented
    private func loginWithSFViewController(url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let viewController = SFSafariViewController(url: url, configuration: SFSafariViewController.Configuration())
            viewController.delegate = self
            self.currentSession = viewController
            
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            guard let presentingViewController = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                self.logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
                continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                return
            }
            
            presentingViewController.present(viewController, animated: true)
            continuation.resume(returning: url)
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
        
        await reset()
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
        Task { @MainActor in
            self.logger.i("User cancelled the authorization process by closing the window")
            await self.reset()
        }
    }
    
    nonisolated public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {}
}
