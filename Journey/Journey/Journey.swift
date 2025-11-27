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
import PingJourneyPlugin

/// A typealias mapping Journey to the underlying Workflow type used by the orchestrator.
public typealias Journey = Workflow

/// Options that influence how a Journey is initiated or resumed.
///
/// - forceAuth: Forces authentication even if a valid session exists.
/// - noSession: Allows the journey to complete without creating a session.
public struct Options: Sendable {
    /// Whether to force authentication even when a valid session exists.
    public var forceAuth: Bool = false
    /// Whether to allow completion without generating a session.
    public var noSession: Bool = false
}

/// Configuration for Journey workflows.
///
/// Conforms to `WorkflowConfig` and `Sendable`, and holds parameters required
/// to communicate with the Journey backend.
/// - Important: Provide `serverUrl` and `realm` appropriate to your deployment.
public class JourneyConfig: WorkflowConfig, @unchecked Sendable {
    /// The base URL of the server handling Journey requests, for example:
    /// https://example.am.com/am
    public var serverUrl: String?
    
    /// The realm used for authentication and callback endpoints.
    /// Defaults to the value in `JourneyConstants.realm`.
    public var realm: String = JourneyConstants.realm
    
    /// The cookie name used by the Journey backend.
    /// Defaults to `JourneyConstants.cookie`.
    public var cookie: String = JourneyConstants.cookie
}

// Define the Journey class
public extension Journey {
    /// Creates a Journey instance with sensible defaults and optional customization.
    ///
    /// This configures:
    /// - Logging and timeout
    /// - Default headers via `CustomHeader.config`
    /// - Node transformation, session management, and OIDC support modules
    /// - Callback registrations for common Journey callbacks
    ///
    /// - Parameter block: An optional configuration closure to customize `JourneyConfig` and modules.
    /// - Returns: A configured Journey.
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
            await CallbackRegistry.shared.register(type: JourneyConstants.booleanAttributeInputCallback, callback: BooleanAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.choiceCallback, callback: ChoiceCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.confirmationCallback, callback: ConfirmationCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.consentMappingCallback, callback: ConsentMappingCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.hiddenValueCallback, callback: HiddenValueCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.kbaCreateCallback, callback: KbaCreateCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.metadataCallback, callback: MetadataCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.nameCallback, callback: NameCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.numberAttributeInputCallback, callback: NumberAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.passwordCallback, callback: PasswordCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.pollingWaitCallback, callback: PollingWaitCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.stringAttributeInputCallback, callback: StringAttributeInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.suspendedTextOutputCallback, callback: SuspendedTextOutputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.termsAndConditionsCallback, callback: TermsAndConditionsCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.textInputCallback, callback: TextInputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.textOutputCallback, callback: TextOutputCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.validatedPasswordCallback, callback: ValidatedPasswordCallback.self)
            await CallbackRegistry.shared.register(type: JourneyConstants.validatedUsernameCallback, callback: ValidatedUsernameCallback.self)
            
            // Optional dynamic registrations for auxiliary modules
            if let c: NSObject.Type = NSClassFromString("PingProtect.ProtectCallbacks") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingExternalIdP.IdpCallbacks") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingDeviceProfile.DeviceProfile") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingFido.CallbackInitializer") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingReCaptchaEnterprise.ReCaptchaEnterprise") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
            if let c: NSObject.Type = NSClassFromString("PingBinding.BindingModule") as? NSObject.Type {
                c.perform(Selector(("registerCallbacks")))
            }
        }
        // Apply custom configuration
        block(config)
        
        return Journey(config: config)
    }
    
    /// Starts a Journey by name with optional options configuration.
    ///
    /// - Parameters:
    ///   - journeyName: The name of the Journey (auth tree) to start.
    ///   - configure: Optional closure to modify `Options` before starting.
    /// - Returns: The first `Node` returned by the Journey start.
    func start(_ journeyName: String, configure: @Sendable (inout Options) -> Void = { _ in }) async -> Node {
        var options = Options()
        configure(&options)
        guard let journeyConfig = self.config as? JourneyConfig else {
            return FailureNode(cause: ApiError.error(400, [:], "JourneyConfig missing"))
        }
        
        self.sharedContext.set(key: JourneyConstants.forceAuth, value: options.forceAuth)
        self.sharedContext.set(key: JourneyConstants.noSession, value: options.noSession)
        
        let request = Request()
        request.populateRequest(authIndexValue: journeyName, journeyConfig: journeyConfig, options: options)
        
        return await start(request)
    }
    
    /// Resumes a Journey from a suspended URI with optional options configuration.
    ///
    /// - Parameters:
    ///   - uri: The resume URI containing the suspendedId parameter.
    ///   - configure: Optional closure to modify `Options` before resuming.
    /// - Returns: The next `Node` returned by the Journey resume, or a `FailureNode` if URI is invalid.
    func resume(_ uri: URL, configure: @Sendable (inout Options) -> Void = { _ in }) async -> Node {
        var options = Options()
        configure(&options)
        guard let journeyConfig = self.config as? JourneyConfig else {
            return FailureNode(cause: ApiError.error(400, [:], "JourneyConfig missing"))
        }
        
        self.sharedContext.set(key: JourneyConstants.forceAuth, value: options.forceAuth)
        self.sharedContext.set(key: JourneyConstants.noSession, value: options.noSession)
        
        if let components = URLComponents(url: uri, resolvingAgainstBaseURL: false),
           let suspendedId = components.queryItems?.first(where: { $0.name == JourneyConstants.suspendedId })?.value {
            let request = Request()
            request.populateRequest(authIndexValue: "", authIndexType: "", journeyConfig: journeyConfig, options: options)
            request.parameter(name: JourneyConstants.suspendedId, value: suspendedId)
            return await start(request)
        } else {
            return FailureNode(cause: ApiError.error(400, [:], "Invalid URI or missing suspendedId"))
        }
    }
    
    /// Signs off the Journey session and performs any configured cleanup.
    ///
    /// - Returns: `.success(())` on success or `.failure(Error)` if sign-off fails.
    func journeySignOff() async -> Result<Void, Error> {
        return await signOff()
    }
    
    /// Sends a request using the configured HTTP client and wraps the response.
    ///
    /// - Parameter request: The request to send.
    /// - Returns: A `Response` containing the raw data and `HTTPURLResponse`.
    private func send(_ request: Request) async throws -> Response {
        let (data, urlResponse) = try await config.httpClient.sendRequest(request: request)
        return HttpResponse(data: data, response: urlResponse)
    }
}

extension Locale {
    /// The user's preferred locales, derived from `Locale.preferredLanguages`.
    public static var preferredLocales: [Locale] {
        Locale.preferredLanguages.map {Locale(identifier: $0)}
    }
}

extension Array where Element == Locale {
    /// Formats locales as a value suitable for the `Accept-Language` HTTP header.
    ///
    /// Produces a comma-separated list of language tags with descending q-values.
    /// The first locale is unweighted; subsequent entries decrement by 0.1 down to a minimum of 0.1.
    ///
    /// - Returns: A properly formatted `Accept-Language` value, or an empty string if no locales.
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

