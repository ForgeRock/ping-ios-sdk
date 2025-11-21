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

public typealias Journey = Workflow

/// Define a struct to hold options for the journey.
/// This struct contains two properties:
/// - `forceAuth`: A boolean indicating whether to force authentication.
/// - `noSession`: A boolean indicating whether to allow the journey to complete without generating a session.
public struct Options: Sendable {
    public var forceAuth: Bool = false
    public var noSession: Bool = false
}

// Define the Journey class
public extension Journey {
    /// Method to create a Journey instance.
    /// - Parameter block: The configuration block.
    /// - Returns: The Journey instance.
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
            CallbackRegistry.shared.register(type: JourneyConstants.booleanAttributeInputCallback, callback: BooleanAttributeInputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.choiceCallback, callback: ChoiceCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.confirmationCallback, callback: ConfirmationCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.consentMappingCallback, callback: ConsentMappingCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.hiddenValueCallback, callback: HiddenValueCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.kbaCreateCallback, callback: KbaCreateCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.metadataCallback, callback: MetadataCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.nameCallback, callback: NameCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.numberAttributeInputCallback, callback: NumberAttributeInputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.passwordCallback, callback: PasswordCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.pollingWaitCallback, callback: PollingWaitCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.stringAttributeInputCallback, callback: StringAttributeInputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.suspendedTextOutputCallback, callback: SuspendedTextOutputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.termsAndConditionsCallback, callback: TermsAndConditionsCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.textInputCallback, callback: TextInputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.textOutputCallback, callback: TextOutputCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.validatedPasswordCallback, callback: ValidatedPasswordCallback.self)
            CallbackRegistry.shared.register(type: JourneyConstants.validatedUsernameCallback, callback: ValidatedUsernameCallback.self)
            
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
    
    /// Starts the journey with the provided login and configuration block.
    /// - Parameters:
    /// - login: The login identifier to start the journey.
    /// - block:  A block to configure the `Options` struct.
    /// - Returns: A `Node` representing the start of the journey.
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
    
    /// Resumes the journey with the provided URI and configuration block.
    /// - Parameters:
    /// - uri: The URI to resume the journey.
    /// - block:  A block to configure the `Options` struct.
    /// - Returns: A `Node` representing the resumed journey.
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
    
    func journeySignOff() async -> Result<Void, Error> {
        return await signOff()
    }
    
    /// Sends a request and returns the response.
    /// - Parameter request: The request to be sent.
    /// - Returns: The response received.
    private func send(_ request: Request) async throws -> Response {
        let (data, urlResponse) = try await config.httpClient.sendRequest(request: request)
        return HttpResponse(data: data, response: urlResponse)
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
