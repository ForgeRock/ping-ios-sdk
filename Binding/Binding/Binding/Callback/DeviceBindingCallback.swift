
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
    
    private enum CodingKeys: String, CodingKey {
        case jws, deviceId, deviceName, clientError
    }
    
    private enum CodingKeys: String, CodingKey {
        case jws, deviceId, deviceName, clientError
    }
    
    public override func initValue(name: String, value: Any) {
        switch name {
        case Constants.userId:
            self.userId = value as? String ?? ""
        case Constants.username:
            self.userName = value as? String ?? ""
        case Constants.challenge:
            self.challenge = value as? String ?? ""
        case Constants.authenticationType:
            if let authType = value as? String {
                self.deviceBindingAuthenticationType = DeviceBindingAuthenticationType(rawValue: authType) ?? .none
            }
        case Constants.title:
            self.title = value as? String ?? ""
        case Constants.subtitle:
            self.subtitle = value as? String ?? ""
        case Constants.description:
            self.description = value as? String ?? ""
        case Constants.timeout:
            self.timeout = value as? Int ?? 60
        case Constants.attestation:
            if let attestationBool = value as? Bool, attestationBool {
                self.attestation = .challenge(self.challenge)
            }
        default:
            break
        }
    }
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        self.input(jws, key: CodingKeys.jws.rawValue)
    }
    
    /// Sets the device ID value in the callback.
    /// - Parameter deviceId: The device ID to be set.
    public func setDeviceId(_ deviceId: String) {
        self.input(deviceId, key: CodingKeys.deviceId.rawValue)
    }
    
    /// Sets the device name value in the callback.
    /// - Parameter deviceName: The device name to be set.
    public func setDeviceName(_ deviceName: String) {
        self.input(deviceName, key: CodingKeys.deviceName.rawValue)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        self.input(clientError, key: CodingKeys.clientError.rawValue)
    }
    
    /// Sets the JWS value in the callback.
    /// - Parameter jws: The JWS to be set.
    public func setJws(_ jws: String) {
        self.input(jws, key: CodingKeys.jws.rawValue)
    }
    
    /// Sets the device ID value in the callback.
    /// - Parameter deviceId: The device ID to be set.
    public func setDeviceId(_ deviceId: String) {
        self.input(deviceId, key: CodingKeys.deviceId.rawValue)
    }
    
    /// Sets the device name value in the callback.
    /// - Parameter deviceName: The device name to be set.
    public func setDeviceName(_ deviceName: String) {
        self.input(deviceName, key: CodingKeys.deviceName.rawValue)
    }
    
    /// Sets the client error value in the callback.
    /// - Parameter clientError: The client error to be set.
    public func setClientError(_ clientError: String) {
        self.input(clientError, key: CodingKeys.clientError.rawValue)
    }
}
