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
    
    /// Initializes the callback with the given name and value.
    /// - Parameters:
    ///   - name: The name of the value.
    ///   - value: The value.
    public override func initValue(name: String, value: Any) {
        switch name {
        case Constants.userId:
            userId = value as? String ?? ""
        case Constants.username:
            userName = value as? String ?? ""
        case Constants.challenge:
            challenge = value as? String ?? ""
        case Constants.authenticationType:
            if let authType = value as? String {
                deviceBindingAuthenticationType = DeviceBindingAuthenticationType(rawValue: authType) ?? .none
            }
        case Constants.title:
            title = value as? String ?? ""
        case Constants.subtitle:
            subtitle = value as? String ?? ""
        case Constants.description:
            description = value as? String ?? ""
        case Constants.timeout:
            timeout = value as? Int ?? 60
        case Constants.attestation:
            if let attestationBool = value as? Bool, attestationBool {
                attestation = .challenge(challenge)
            }
        default:
            break
        }
    }
    
    /// Sets the JWS on the callback.
    /// - Parameter jws: The JWS to set.
    public func setJws(_ jws: String) {
        updateInputValue(jws, for: Constants.jws)
    }
    
    /// Sets the device ID on the callback.
    /// - Parameter deviceId: The device ID to set.
    public func setDeviceId(_ deviceId: String) {
        updateInputValue(deviceId, for: Constants.deviceId)
    }
    
    /// Sets the device name on the callback.
    /// - Parameter deviceName: The device name to set.
    public func setDeviceName(_ deviceName: String) {
        updateInputValue(deviceName, for: Constants.deviceName)
    }
    
    /// Binds a device to a user account.
    /// - Parameter config: A closure to configure the `DeviceBindingConfig`.
    public func bind(config: (DeviceBindingConfig) -> Void = { _ in }) async throws {
        _ = try await PingBinder.bind(callback: self, config: config)
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
