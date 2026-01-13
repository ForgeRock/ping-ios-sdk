//
//  QRScannerViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI

/// ViewModel to handle QR code scanning and registration.
/// Processes scanned QR codes for OATH and Push authentication registration.
@MainActor
class QRScannerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var registrationSuccess = false

    func handleScannedCode(_ code: String) async {
        print("QRScanner: Scanned code: \(code)")
        guard !isLoading else {
            print("QRScanner: Already loading, ignoring scan")
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        registrationSuccess = false

        do {
            if code.lowercased().hasPrefix("otpauth://") {
                print("QRScanner: Detected OATH QR code")
                _ = try await registerOathAccount(uri: code)
            } else if code.lowercased().hasPrefix("pushauth://") {
                print("QRScanner: Detected Push QR code")
                _ = try await registerPushAccount(uri: code)
            } else if code.lowercased().hasPrefix("mfauth://") {
                print("QRScanner: Detected Combined MFA QR code")
                try await registerCombinedMfaAccount(uri: code)
            } else {
                print("QRScanner: Unsupported QR code format")
                errorMessage = "Unsupported QR code format. Please scan a valid OATH or Push authentication QR code."
            }
        } catch {
            print("QRScanner: Registration failed with error: \(error)")
            errorMessage = "Registration failed: \(error.localizedDescription)"
        }

        isLoading = false
        print("QRScanner: Processing complete. Success: \(successMessage ?? "nil"), Error: \(errorMessage ?? "nil")")
    }

    private func registerOathAccount(uri: String, publishState: Bool = true) async throws -> String {
        if ConfigurationManager.shared.oathClient == nil {
            try await ConfigurationManager.shared.initializeOathClient()
        }
        guard let oathClient = ConfigurationManager.shared.oathClient else {
            throw NSError(domain: "ManualRegistration", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize OATH client"])
        }

        let credential = try await oathClient.addCredentialFromUri(uri)
        let message = "Successfully registered OATH account: \(credential.issuer)"
        if publishState {
            successMessage = message
            registrationSuccess = true
        }
        return message
    }

    private func registerPushAccount(uri: String, publishState: Bool = true) async throws -> String {
        if ConfigurationManager.shared.pushClient == nil {
            try await ConfigurationManager.shared.initializePushClient()
        }
        guard let pushClient = ConfigurationManager.shared.pushClient else {
            throw NSError(domain: "QRScanner", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize Push client"])
        }

        let credential = try await pushClient.addCredentialFromUri(uri)
        let message = "Successfully registered Push account: \(credential.issuer)"
        if publishState {
            successMessage = message
            registrationSuccess = true
        }
        return message
    }
    
    private func registerCombinedMfaAccount(uri: String) async throws {
        let pushMessage = try await registerPushAccount(uri: uri, publishState: false)
        let oathMessage = try await registerOathAccount(uri: uri, publishState: false)
        successMessage = [pushMessage, oathMessage].joined(separator: "\n")
        registrationSuccess = true
    }
}
