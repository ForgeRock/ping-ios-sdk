//
//  PingOneMFAPayloadViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOneMFA

/// ViewModel for the PingOne MFA Payload screen.
/// Lazily initializes the SDK, then fetches the mobile payload string once on load.
@MainActor
class PingOneMFAPayloadViewModel: ObservableObject {
    @Published var payload: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// Loads the mobile payload from the SDK.
    /// Lazily initializes the PingOne MFA SDK if it has not been initialized yet.
    func loadPayload() async {
        guard !ConfigurationManager.shared.isPingOneMFAInitialized else {
            await fetchPayload()
            return
        }

        isLoading = true
        do {
            try await ConfigurationManager.shared.initializePingOneMFAClient()
        } catch {
            errorMessage = "Failed to initialize PingOne MFA: \(error.localizedDescription)"
            isLoading = false
            return
        }
        await fetchPayload()
    }

    // MARK: - Private

    private func fetchPayload() async {
        isLoading = true
        errorMessage = nil

        do {
            payload = try await PingOneMFA.generateMobilePayload()
        } catch {
            errorMessage = "Failed to collect mobile payload: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
