//
//  PingOneMFAScannerViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import PingOneMFA

/// ViewModel to handle QR code scanning and pairing for PingOne MFA.
/// Processes the raw scanned string and passes it directly to `PingOneMFA.pair(pairingKey:)`.
@MainActor
class PingOneMFAScannerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var registrationSuccess = false

    func handleScannedCode(_ code: String) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        registrationSuccess = false

        do {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
            try await PingOneMFA.pair(pairingKey: code)
            successMessage = "Successfully paired with PingOne MFA."
            registrationSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
