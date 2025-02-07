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

public class BrowserLauncher: NSObject {
    
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
        return try await withCheckedThrowingContinuation {continuation in
            switch browserType {
            case .nativeBrowserApp:
                break
            case .sfViewController:
                break
            case .authSession:
                asWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, prefersEphemeralWebBrowserSession: false) { result in
                    self.isInProgress = false
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
}

extension BrowserLauncher: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
