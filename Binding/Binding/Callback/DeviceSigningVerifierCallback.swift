/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingJourney

/// A Journey callback for handling device signing verification.
public class DeviceSigningVerifierCallback: AbstractCallback, @unchecked Sendable {
    
    /// The user ID for the signing.
    public var userId: String?
    /// The challenge to be signed.
    public var challenge: String = ""
    /// The title to be displayed in the UI.
    public var title: String = ""
    /// The subtitle to be displayed in the UI.
    public var subtitle: String = ""
    /// The description to be displayed in the UI.
    public var description: String = ""
    /// The timeout for the operation.
    public var timeout: Int = 30
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        updateInputValue(jws, for: Constants.jws)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        updateInputValue(clientError, for: Constants.clientError)
    }
    
    /// Signs a challenge with a previously bound device.
    /// - Parameter config: A closure to configure the `DeviceBindingConfig`.
    public func sign(config: (DeviceBindingConfig) -> Void = { _ in }) async throws {
        _ = try await PingBinder.sign(callback: self, config: config)
    }
    
    private func updateInputValue(_ value: Any, for name: String) {
        guard var inputArray = json[JourneyConstants.input] as? [[String: Any]] else {
            return
        }
        
        if let index = inputArray.firstIndex(where: { $0[JourneyConstants.name] as? String == name }) {
            inputArray[index][JourneyConstants.value] = value
            json[JourneyConstants.input] = inputArray
        }
    }
}
