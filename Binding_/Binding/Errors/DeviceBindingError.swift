
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation

/// An enum representing the possible errors that can occur during device binding.
public enum DeviceBindingError: Error {
    /// The device is not supported.
    case deviceNotSupported
    /// The device is not registered.
    case deviceNotRegistered
    /// An invalid claim was used.
    case invalidClaim
    /// Biometric authentication failed.
    case biometricError(Error)
    /// The user cancelled the operation.
    case userCanceled
    /// An unknown error occurred.
    case unknown
}
