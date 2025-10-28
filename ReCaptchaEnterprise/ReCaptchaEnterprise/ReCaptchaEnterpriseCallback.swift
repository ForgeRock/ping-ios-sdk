// 
//  ReCaptchaEnterpriseCallback.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingJourney
import PingLogger
@_exported import RecaptchaEnterprise

// MARK: - ReCaptchaEnterpriseCallback

/// A callback implementation for executing Google reCAPTCHA Enterprise verification.
///
/// This callback is used within the Ping Identity journey framework to perform
/// bot detection and fraud prevention using Google's reCAPTCHA Enterprise service.
/// It extends AbstractCallback for modern Swift callback handling and provides
/// a streamlined interface for reCAPTCHA execution.
///
/// ## Usage in Journey Flow
/// 1. Server sends callback with reCAPTCHA site key and input field configuration
/// 2. Callback receives configuration via `initValue` calls
/// 3. Client calls `verify()` to obtain reCAPTCHA token
/// 4. Token and action are submitted back to server for verification
///
/// ## Security Considerations
/// - Never expose site keys in client code
/// - Handle errors gracefully without exposing implementation details
/// - Use appropriate actions for different user flows
public class ReCaptchaEnterpriseCallback: AbstractCallback, @unchecked Sendable {
    
    // MARK: - Configuration Properties
    
    /// The reCAPTCHA Enterprise site key provided by the server.
    /// This key identifies your site to Google's reCAPTCHA service.
    private(set) public var recaptchaSiteKey: String = ""
    
    /// The name of the input field for the reCAPTCHA token.
    /// This is determined from the server configuration.
    private(set) public var tokenKey: String = ""
    
    /// The name of the input field for the action.
    /// This is determined from the server configuration.
    private(set) public var actionKey: String = ""
    
    /// The name of the input field for client errors.
    /// This is determined from the server configuration.
    private(set) public var clientErrorKey: String = ""
    
    /// The name of the input field for additional payload.
    /// This is determined from the server configuration.
    private(set) public var payloadKey: String = ""
    
    
    // MARK: - Initialization
    
    /// Initializes callback properties based on server-provided configuration.
    ///
    /// This method is called automatically during callback initialization to set up
    /// the callback based on the server's requirements for reCAPTCHA verification.
    ///
    /// - Parameters:
    ///   - name: The name of the property being initialized
    ///   - value: The value containing the property configuration
    ///
    /// ## Supported Properties
    /// - `recaptchaSiteKey`: String containing the reCAPTCHA site key
    /// - Input field names are detected from input keys containing specific keywords
    public override func initValue(name: String, value: Any) {
        switch name {
        case JourneyConstants.recaptchaSiteKey:
            if let stringValue = value as? String {
                self.recaptchaSiteKey = stringValue
            }
        default:
            break
        }
    }
    
    // MARK: - Execution Methods
    
    /// Executes reCAPTCHA Enterprise verification and submits the result to the server.
    ///
    /// This method orchestrates the complete reCAPTCHA verification process,
    /// allowing for custom configuration of the execution parameters.
    ///
    /// - Parameter configBlock: Configuration block for customizing reCAPTCHA execution
    /// - Returns: Result containing the reCAPTCHA token or an error
    ///
    /// ## Execution Process
    /// 1. Creates ReCaptchaEnterpriseConfig with default settings
    /// 2. Applies custom configuration via configBlock
    /// 3. Fetches reCAPTCHA client with site key
    /// 4. Executes reCAPTCHA action with specified timeout
    /// 5. Submits token and action to server
    ///
    /// ## Configuration Example
    /// ```swift
    /// let result = await callback.verify { config in
    ///     config.action = "signup"
    ///     config.timeout = 20000
    ///     config.provider = CustomRecaptchaProvider()
    /// }
    /// ```
    ///
    /// ## Error Handling
    /// - Returns .failure for execution or network errors
    /// - Returns .success with the reCAPTCHA token
    /// - Automatically submits successful results to server
    /// - Client errors are captured and submitted to server
    public func verify(
        configBlock: @escaping @Sendable (ReCaptchaEnterpriseConfig) -> Void = {_ in }
    ) async -> Result<String, Error> {
        
        // Create configuration with defaults
        let config = ReCaptchaEnterpriseConfig()
        
        // Apply custom configuration
        configBlock(config)
        
        setPayload(config.payload)
        
        do {
            // Fetch reCAPTCHA client
            let recaptchaClient = try await Recaptcha.fetchClient(withSiteKey: recaptchaSiteKey)
            
            // Create reCAPTCHA action
            let recaptchaAction = RecaptchaAction(customAction: config.action)
            
            // Execute reCAPTCHA
            let token = try await recaptchaClient.execute(
                withAction: recaptchaAction,
                withTimeout: config.timeout
            )
            
            // Submit to server
            setAction(config.action)
            setToken(token)
            
            config.logger.i("reCAPTCHA Enterprise token obtained successfully")
            
            return .success(token)
            
        } catch {
            config.logger.e("reCAPTCHA Enterprise execution failed: \(error.localizedDescription)", error: error)
            setClientError(error.localizedDescription)
            return .failure(error)
        }
    }
    
    // MARK: - Input Setting Methods
    
    /// Sets the reCAPTCHA token value in the callback response.
    /// - Parameter value: String value of the reCAPTCHA token
    public func setToken(_ value: String) {
        _ = updateInput(at: 0, value: value)
    }
    
    /// Sets the action value in the callback response.
    /// - Parameter value: String value of the action
    internal func setAction(_ value: String) {
        _ = updateInput(at: 1, value: value)
    }
    
    /// Sets the client error value in the callback response.
    /// - Parameter value: String value of the error message
    public func setClientError(_ value: String) {
        _ = updateInput(at: 2, value: value)
    }
    
    /// Sets additional payload value for the reCAPTCHA in callback response.
    /// - Parameter value: Dictionary value of additional data
    public func setPayload(_ value: [String: Any]? = nil) {
        if let payload = value, !payload.isEmpty {
            let jsonString = ReCaptchaEnterpriseUtils.jsonStringify(
                value: payload as AnyObject
            )
            _ = updateInput(at: 3, value: jsonString)
        }
    }
    
    /// Returns the payload for the callback submission.
    /// - Returns: JSON dictionary for server submission
    public override func payload() -> [String: Any] {
        return json
    }
}

// MARK: - ReCaptchaEnterpriseConfig

/// Configuration object for customizing reCAPTCHA Enterprise execution.
///
/// This class allows fine-grained control over reCAPTCHA behavior
/// including action names, timeouts, and provider customization.
public final class ReCaptchaEnterpriseConfig: @unchecked Sendable {
    
    /// The action name to associate with this reCAPTCHA execution.
    /// Different actions can be used for different user flows (login, signup, etc.)
    /// Default value is "login"
    public var action: String = ReCaptchaEnterpriseConstants.defaultAction
    
    /// Timeout for reCAPTCHA execution in milliseconds.
    /// Default value is 15000 (15 seconds)
    public var timeout: Double = ReCaptchaEnterpriseConstants.defaultTimeout
    
    /// Logger instance for recording reCAPTCHA events
    public var logger: Logger = LogManager.warning
    
    /// Sets additional payload value for the reCAPTCHA in callback response.
    /// Dictionary value of additional data
    public var payload: [String: Any]? = nil
    
    /// Initializes a new instance of `ReCaptchaEnterpriseConfig`
    public init() {}
}
