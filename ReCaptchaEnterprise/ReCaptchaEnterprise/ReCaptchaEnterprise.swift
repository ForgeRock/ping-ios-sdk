// 
//  ReCaptchaEnterprise.swift
//  ReCaptchaEnterprise
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingJourneyPlugin

@objc
class ReCaptchaEnterprise: NSObject {
    /// Registers the ReCaptchaEnterpriseCallback with the collector factory
    @objc
    public static func registerCallbacks() {
        Task {
            await CallbackRegistry.shared.register(type: JourneyConstants.reCaptchaEnterpriseCallback, callback: ReCaptchaEnterpriseCallback.self)
        }
    }
}

extension JourneyConstants {
    /// Constant identifier for the reCAPTCHA Enterprise callback type.
    /// This value is used by the server to indicate that reCAPTCHA verification
    /// is required during the authentication journey.
    public static let reCaptchaEnterpriseCallback = "ReCaptchaEnterpriseCallback"
    
    /// Key for reCAPTCHA site key configuration property
    static let recaptchaSiteKey = "recaptchaSiteKey"
    
    /// Key for token input property
    static let token = "token"
    
    /// Key for action input property
    static let action = "action"
    
    /// Key for client error input property
    static let clientError = "clientError"
    
    /// Key for additional payload input property
    static let payload = "payload"
}

/// Represents various constants used in ReCaptchaEnterprise module
public enum ReCaptchaEnterpriseConstants {
    /// Error message for invalid token
    public static let invalidToken = "INVALID_CAPTCHA_TOKEN"
    
    /// Default action name for reCAPTCHA execution
    public static let defaultAction = "login"
    
    /// Default timeout in milliseconds
    public static let defaultTimeout: Double = 15000
}
