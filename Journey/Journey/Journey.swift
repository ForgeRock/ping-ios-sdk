// 
//  Journey.swift
//  Journey
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc
import PingLogger

public typealias Journey = Workflow

// Define a configuration object
public class JourneyConfig: WorkflowConfig, @unchecked Sendable {
    public var serverUrl: String?
    public var realm: String = JourneyConstants.realm
    public var cookie: String = JourneyConstants.cookie
    public var forceAuth: Bool = false
    public var noSession: Bool = false
}

// Define the Journey class
public extension Journey {
    static func createJourney(block: @Sendable (JourneyConfig) -> Void = {_ in }) -> Journey {
        let config = JourneyConfig()
        config.logger = LogManager.standard
        config.timeout = 30
        config.module(CustomHeader.config) { customHeaderConfig in
            customHeaderConfig.header(name: Request.Constants.xRequestedWith, value: Request.Constants.pingSdk)
            customHeaderConfig.header(name: Request.Constants.xRequestedPlatform, value: Request.Constants.ios)
            customHeaderConfig.header(name: Request.Constants.acceptLanguage, value: Locale.preferredLocales.toAcceptLanguage())
        }
        
        config.module(NodeTransformModule.config)
        config.module(SessionModule.config)
        config.module(OidcModule.config)
        
        Task {
            await CallbackRegistry.shared.registerDefaultCallbacks()
        }
        
        // Apply custom configuration
        block(config)
        
        return Journey(config: config)
    }
    
    func start(_ login: String, block: @Sendable (JourneyConfig) -> Void = {_ in }) async -> Node {
        let journeyConfig = self.config as! JourneyConfig
        block(journeyConfig)
        
        let request = Request()
        request.populateRequest(authIndexValue: login, journeyConfig: journeyConfig)
        
        do {
            return try await start(request: request)
        } catch {
            return FailureNode(cause: error)
        }
    }
}

extension Locale {
    /// Returns an array of `Locale` objects corresponding to the user's preferred languages.
    public static var preferredLocales: [Locale] {
        Locale.preferredLanguages.map {Locale(identifier: $0)}
    }
}

extension Array where Element == Locale {
    /// Converts an array of `Locale` objects to an `Accept-Language` header value.
    /// This method creates a comma-separated string where each locale is represented by its identifier,
    /// optionally with a quality (`q`) value. The first locale is added without a quality value, and subsequent
    /// locales are appended with a quality value that decreases by 0.1 for each additional locale.
    ///
    /// - Returns: A `String` formatted as an `Accept-Language` header value.
    public func toAcceptLanguage() -> String {
        if isEmpty { return "" }
        
        var languageTags: [String] = []
        var currentQValue = 0.9
        
        for (index, locale) in enumerated() {
            // Add language tag version first
            if index == 0 {
                languageTags.append(locale.identifier)
                currentQValue = 0.9
            } else {
                languageTags.append("\(locale.identifier);q=\(String(format: "%.1f", currentQValue))")
                currentQValue = Swift.max(0.1, currentQValue - 0.1)
            }
            
            // Add language version with next q-value
            let languageCode = locale.languageCode ?? ""
            if locale.identifier != languageCode && !languageCode.isEmpty {
                languageTags.append("\(languageCode);q=\(String(format: "%.1f", currentQValue))")
                currentQValue = Swift.max(0.1, currentQValue - 0.1)
            }
        }
        
        return languageTags.joined(separator: ", ")
    }
}
