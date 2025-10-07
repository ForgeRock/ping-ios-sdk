//
//  CallbackInitializer.swift
//  Fido
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney

/// A class responsible for registering FIDO callbacks with the Journey framework.
public class CallbackInitializer: NSObject {
    /// Registers the FIDO callbacks with the `CallbackRegistry`.
    @objc public static func registerCallbacks() {
        CallbackRegistry.shared.register(type: FidoConstants.FIDO2_REGISTRATION_CALLBACK, callback: Fido2RegistrationCallback.self)
        CallbackRegistry.shared.register(type: FidoConstants.FIDO2_AUTHENTICATION_CALLBACK, callback: Fido2AuthenticationCallback.self)
    }
}
