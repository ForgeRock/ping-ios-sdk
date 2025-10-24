
/*
 * Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
 *
 * This software may be modified and distributed under the terms
 * of the MIT license. See the LICENSE file for details.
 */

import Foundation
import PingJourney

/// A Journey callback for handling device binding.
public class DeviceBindingCallback: AbstractCallback, @unchecked Sendable {
    
    /// The user ID for the binding.
    public var userId: String = ""
    /// The username for the binding.
    public var userName: String = ""
    /// The challenge to be signed.
    public var challenge: String = ""
    /// The type of authentication to be used.
    public var deviceBindingAuthenticationType: DeviceBindingAuthenticationType = .none
    /// The title to be displayed in the UI.
    public var title: String = ""
    /// The subtitle to be displayed in the UI.
    public var subtitle: String = ""
    /// The description to be displayed in the UI.
    public var description: String = ""
    /// The timeout for the operation.
    public var timeout: Int = 60
    /// The attestation option.
    public var attestation: Attestation = .none
    
    public required init(json: [String : Any]) throws {
        try super.init(json: json)
        userId = getOutputValue(key: Constants.userId) ?? ""
        userName = getOutputValue(key: Constants.username) ?? ""
        challenge = getOutputValue(key: Constants.challenge) ?? ""
        if let authType: String = getOutputValue(key: Constants.authenticationType) {
            deviceBindingAuthenticationType = DeviceBindingAuthenticationType(rawValue: authType) ?? .none
        }
        title = getOutputValue(key: Constants.title) ?? ""
        subtitle = getOutputValue(key: Constants.subtitle) ?? ""
        description = getOutputValue(key: Constants.description) ?? ""
        timeout = getOutputValue(key: Constants.timeout) ?? 60
        if let attestationBool: Bool = getOutputValue(key: Constants.attestation), attestationBool {
            attestation = .challenge(challenge)
        }
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        self.setInputValue(jws, for: Constants.jws)
    }
    
    /// Sets the device ID value in the callback.
    /// - Parameter deviceId: The device ID to be set.
    public func setDeviceId(_ deviceId: String) {
        self.setInputValue(deviceId, for: Constants.deviceId)
    }
    
    /// Sets the device name value in the callback.
    /// - Parameter deviceName: The device name to be set.
    public func setDeviceName(_ deviceName: String) {
        self.setInputValue(deviceName, for: Constants.deviceName)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        self.setInputValue(clientError, for: Constants.clientError)
    }
}
