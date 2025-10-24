
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// An enum representing the type of device binding authentication.
public enum DeviceBindingAuthenticationType: String, Codable {
    /// Biometric authentication is required.
    case biometric = "BIOMETRIC_ONLY"
    /// No authentication is required.
    case none = "NONE"
}
