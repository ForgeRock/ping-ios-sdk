
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingJourney

public class BindingModule {
    
    public init() {}
    
    public static func register() {
        CallbackRegistry.shared.register(type: "DeviceBindingCallback", callback: DeviceBindingCallback.self)
        CallbackRegistry.shared.register(type: "DeviceSigningVerifierCallback", callback: DeviceSigningVerifierCallback.self)
    }
}
