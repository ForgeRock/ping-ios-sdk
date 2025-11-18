//
//  DeviceBindingCallback.swift
//  PingBinding
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingJourney
import PingOrchestrate

/// A Journey callback for handling device binding.
/// This callback is received from the AIC authentication flow when a device needs to be bound to a user account.
public class DeviceBindingCallback: AbstractCallback, @unchecked Sendable, JourneyAware, ContinueNodeAware {
    /// The `Journey` object associated with the current authentication flow.
    public var journey: Journey?
    /// The `ContinueNode` object that can be used to continue the authentication flow.
    public var continueNode: ContinueNode?
    
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
    /// This method is called by the `Journey` framework to initialize the callback with the values from the server.
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
    /// This method is called by the `PingBinder` after successfully signing the challenge.
    /// - Parameter jws: The JWS to set.
    public func setJws(_ jws: String) {
        updateInputValue(jws, for: Constants.jws)
    }
    
    /// Sets the device ID on the callback.
    /// This method is called by the `PingBinder` after successfully binding the device.
    /// - Parameter deviceId: The device ID to set.
    public func setDeviceId(_ deviceId: String) {
        updateInputValue(deviceId, for: Constants.deviceId)
    }
    
    /// Sets the device name on the callback.
    /// This method is called by the `PingBinder` after successfully binding the device.
    /// - Parameter deviceName: The device name to set.
    public func setDeviceName(_ deviceName: String) {
        updateInputValue(deviceName, for: Constants.deviceName)
    }
    
    /// Sets the client error on the callback.
    /// This method is called when an error occurs during the binding process.
    /// - Parameter error: The error to set.
    private func setClientError(_ error: String) {
        updateInputValue(error, for: Constants.clientError)
    }
    
    /// Binds a device to a user account.
    /// This method calls the `PingBinder` to perform the binding operation.
    /// - Parameter config: A closure to configure the `DeviceBindingConfig`.
    /// - Returns: A `Result` containing the callback's JSON representation or an `Error`.
    public func bind(config: (DeviceBindingConfig) -> Void = { _ in }) async -> Result<[String: Any], Error> {
        do {
            _ = try await Binding.bind(callback: self, journey: self.journey, config: config)
            return .success(self.json)
        } catch {
            let deviceBindingStatus = mapError(error)
            setClientError(deviceBindingStatus.clientError)
            return .failure(deviceBindingStatus)
        }
    }
    
    /// Maps an `Error` to a `DeviceBindingStatus`.
    /// - Parameter error: The error to map.
    /// - Returns: A `DeviceBindingStatus` representing the error.
    private func mapError(_ error: Error) -> DeviceBindingStatus {
        if let deviceBindingError = error as? DeviceBindingError {
            switch deviceBindingError {
            case .deviceNotSupported:
                return .unsupported(errorMessage: nil)
            case .deviceNotRegistered:
                return .clientNotRegistered
            case .invalidClaim:
                return .invalidCustomClaims
            case .biometricError:
                return .unAuthorize
            case .userCanceled:
                return .abort
            case .unknown:
                return .unsupported(errorMessage: "An unknown error occurred.")
            case .authenticationFailed:
                return .unAuthorize
            case .timeout:
                return .timeout
            case .unsupported(errorMessage: let errorMessage):
                return .unsupported(errorMessage: errorMessage)
            }
        }
        return .unsupported(errorMessage: error.localizedDescription)
    }
    
    /// Updates an input value in the callback's JSON representation.
    /// - Parameters:
    ///   - value: The new value.
    ///   - name: The name of the input value to update.
    private func updateInputValue(_ value: Any, for name: String) {
        guard var inputArray = json[JourneyConstants.input] as? [[String: Any]] else {
            return
        }
        
        if let index = inputArray.firstIndex(where: { ($0[JourneyConstants.name] as? String)?.hasSuffix(name) ?? false }) {
            inputArray[index][JourneyConstants.value] = value
            json[JourneyConstants.input] = inputArray
        }
    }
}

