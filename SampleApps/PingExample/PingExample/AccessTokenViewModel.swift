//
//  AccessTokenViewModel.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import PingLogger
import PingOidc

/// A view model responsible for managing the access token state.
/// - This class handles fetching the access token using the DaVinci SDK and logs the results.
/// - Provides an observable published property for UI updates.
@MainActor
class AccessTokenViewModel: ObservableObject {
    /// Published property to hold the current access token.
    /// - Updates are published to the UI whenever the value changes.
    @Published var accessToken: String = ""
    
    /// Initializes the `TokenViewModel` and fetches the access token asynchronously.
    init() {
        Task {
            await accessToken()
        }
    }
    
    /// Fetches the access token using the DaVinci SDK.
    /// - The method checks for a successful token retrieval and updates the `accessToken` property.
    /// - Logs the success or failure result using `PingLogger`.
    func accessToken() async {
        let token = try? await ConfigurationManager.shared.currentUser?.token()
        switch token {
        case .success(let accessToken):
            await MainActor.run {
                self.accessToken = String(describing: accessToken)
            }
            LogManager.standard.i("AccessToken: \(self.accessToken)")
        case .failure(let error):
            await MainActor.run {
                self.accessToken = "Error: \(error.localizedDescription)"
            }
            LogManager.standard.e("", error: error)
        case .none:
            break
        }
    }
}
