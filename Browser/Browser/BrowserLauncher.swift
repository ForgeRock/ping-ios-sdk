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

public enum BrowserType: Int {
    case nativeBrowserApp = 1
    case sfViewController = 2
    case authSession = 0
    case ephemeralAuthSession = 3
}

public enum BrowserError: Error {
    case externalUserAgentFailure
    case externalUserAgentAuthenticationInProgress
    case externalUserAgentCancelled
}

public enum BrowserMode {
    case login
    case logout
    case custom
}

public class BrowserLauncher: NSObject, @unchecked Sendable {
    
    // MARK: Properties
    
    /// Static shared instance of current Browser object
    public static var currentBrowser: BrowserLauncher? = BrowserLauncher()
    /// Boolean indicator whether or not current Browser object is in progress
    public var isInProgress: Bool = false
    /// Custom URL query parameter for /authorize request
    var customParams: [String: String] = [:]
    /// Type of external user-agent; Authentication Service, Native Browser App, or SFSafariViewController
    var browserType: BrowserType = .authSession
    /// Current external user-agent instance
    var currentSession: Any?
    /// Browser mode (either login, logout or custom)
    var browserMode: BrowserMode = .login
    
    var logger: Logger = LogManager.logger {
        didSet {
            // Propagate the logger to Modules
            LogManager.logger = logger
        }
    }
    // MARK: Public Methods
    public func reset() {
        // Reset the browser
        self.isInProgress = false
        self.currentSession = nil
    }
    
    public func launch(url: URL, customParams: [String: String]? = nil,
                       browserType: BrowserType = .authSession, browserMode: BrowserMode = .login, callbackURLScheme: String) async throws -> URL {
        
        //  Or make sure that either same Browser instance or other Browser instance is currently running
        if let isInProgress = BrowserLauncher.currentBrowser?.isInProgress, isInProgress {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        else if self.isInProgress == true {
            throw BrowserError.externalUserAgentAuthenticationInProgress
        }
        
        self.isInProgress = true
        // Launch the browser
        return try await withCheckedThrowingContinuation { continuation in
            switch browserType {
            case .nativeBrowserApp:
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:]) { [weak self] (result) in
                        if result {
                            self?.logger.i("BrowserLauncher: Native Browser launched successfully")
                            continuation.resume(returning: url)
                        }
                        else {
                            continuation.resume(throwing: BrowserError.externalUserAgentFailure)
                            self?.close()
                            self?.reset()
                        }
                    }
                }
            case .sfViewController:
                isInProgress = true
                loginWithSFViewController(url: url) { [weak self] result in
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        self?.isInProgress = false
                        self?.close()
                        self?.reset()
                        continuation.resume(throwing: error)
                    }
                }
            case .authSession:
                asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: false) { [weak self] result in
                    self?.isInProgress = false
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            case .ephemeralAuthSession:
                asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: true) { result in
                    self.isInProgress = false
                    switch result {
                    case .success(let url):
                        continuation.resume(returning: url)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    // MARK: Private Methods
    
    /// Performs authentication through /authorize endpoint using SFSafariViewController
    /// - Parameters:
    ///   - url: URL of /authorize including all URL query parameter
    ///   - completion: Completion callback to nofiy the result
    /// - Returns: Boolean indicator whether or not launching external user-agent was successful
    private func loginWithSFViewController(url: URL,
                                           completion: @escaping (Result<URL, Error>) -> Void) {
        var viewController: SFSafariViewController?
        viewController = SFSafariViewController(url: url, configuration: SFSafariViewController.Configuration())
        viewController?.delegate = self
        self.currentSession = viewController
        DispatchQueue.main.async {
            let presentingViewController = UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.rootViewController
            if let currentViewController = presentingViewController, let sfVC = viewController {
                currentViewController.present(sfVC, animated: true)
                completion(.success(url))
            }
            else {
                self.logger.e("Fail to launch SFSafariViewController; missing presenting ViewController", error: nil)
                completion(.failure(BrowserError.externalUserAgentFailure))
            }
        }
    }
    
    private func asWebAuthenticationSession(url: URL, callbackURLScheme: String,
                                            prefersEphemeralWebBrowserSession: Bool,
                                            completion: @escaping (Result<URL, Error>) -> Void) {
        let authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { (url, error) in
            if let error = error {
                completion(.failure(error))
            } else if let url = url {
                completion(.success(url))
            } else {
                completion(.failure(BrowserError.externalUserAgentFailure))
            }
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else{
                return
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
            self.currentSession = authSession
            authSession.start()
        }
    }
    
    /// Closes currently presenting ViewController
    private func close() {
        if let sfViewController = self.currentSession as? SFSafariViewController {
            self.logger.i("Close called with SFSafariViewController: \(String(describing: self.currentSession))")
            DispatchQueue.main.async {
                sfViewController.dismiss(animated: true, completion: nil)
            }
        }
        
        if let asAuthSession = self.currentSession as? ASWebAuthenticationSession {
            self.logger.i("Close called with iOS 12 or above: \(String(describing: self.currentSession))")
            DispatchQueue.main.async {
                asAuthSession.cancel()
            }
        }
    }
}

extension BrowserLauncher: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

extension BrowserLauncher: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        self.logger.i("User cancelled the authorization process by closing the window")
        self.reset()
    }
    
    public func safariViewController(_ controller: SFSafariViewController, initialLoadDidRedirectTo URL: URL) {}
}
