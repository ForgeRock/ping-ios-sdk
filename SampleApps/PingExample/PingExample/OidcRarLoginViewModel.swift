//
//  OidcRarLoginViewModel.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingOrchestrate
import PingOidc
import PingLogger

@MainActor
class OidcRarLoginViewModel: ObservableObject {
    /// The authorization_details JSON the user is editing.
    @Published var jsonText: String = RarPreset.paymentInitiation.json
    /// Live validation message (nil when valid or empty).
    @Published var validationError: String?
    /// The result of the last login attempt.
    @Published var state: Result<User, OidcError>?
    @Published var isLoading: Bool = false

    let configManager = ConfigurationManager.shared

    /// The currently selected OIDC (Web) configuration, if any.
    var selectedConfig: Configuration? {
        configManager.selectedConfig(for: .oidcWeb)
    }

    /// Whether PAR is enabled on the selected configuration.
    var parEnabled: Bool {
        selectedConfig?.par ?? false
    }

    /// Whether the selected configuration carries config-level authorization details.
    var configLevelDetailsSet: Bool {
        guard let json = selectedConfig?.authorizationDetailsJson else { return false }
        if case .success = RarJson.decode(json) { return true }
        return false
    }

    /// Validates the current text, returning the decoded details when valid.
    func validate() -> [AuthorizationDetail]? {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = nil
            return nil
        }
        switch RarJson.decode(trimmed) {
        case .success(let details):
            validationError = nil
            return details
        case .failure(let error):
            validationError = error.message
            return nil
        }
    }

    /// Starts the OIDC login with per-transaction authorization details (the PAR-safe path).
    func login(details: [AuthorizationDetail]) {
        isLoading = true
        Task {
            defer { isLoading = false }
            guard let oidcLogin = oidcLogin else { return }
            do {
                self.state = try await oidcLogin.authorize { options in
                    options.authorizationDetails = details
                }
            } catch let error as OidcError {
                self.state = .failure(error)
            } catch {
                self.state = .failure(.unknown(cause: error))
            }
        }
    }
}
