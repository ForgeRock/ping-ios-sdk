//
//  IdpCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingExternalIdP

struct IdpCallbackView: View {
    @StateObject var viewModel: IdpCallbackViewModel
    
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            switch viewModel.authState {
            case .authenticating:
                Image(systemName: "person.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PingTheme.Color.contentInverse)
                Text(viewModel.callback.provider)
                    .pingBodySecondary()
                Button("Continue") {
                    Task {
                        if viewModel.hasStartedAuthorization == false {
                            // Call the performAuthorization method to start the process.
                            await viewModel.performAuthorization()
                        }
                    }
                }
                .buttonStyle(.pingPrimary)
            case .failure(let error):
                Image(systemName: "xmark.octagon.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PingTheme.Color.statusError)
                Text("Authorization failed: \(error.localizedDescription)")
                    .pingBodySecondary()
                    .multilineTextAlignment(.center)
                Button("Continue") {
                    Task {
                        onNext()
                    }
                }
                .buttonStyle(.pingSecondary)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(PingTheme.Color.statusSuccess)
                Text("Authorization Successful")
                    .pingBodySecondary()
                    .multilineTextAlignment(.center)
                Button("Continue") {
                    Task {
                        onNext()
                    }
                }
                .buttonStyle(.pingPrimary)
            }
        }
        // Edge spacing comes from CallbackView's screen padding; no own inset.
    }
}

@MainActor
class IdpCallbackViewModel: ObservableObject {
    
    @Published var authState: AuthState = .authenticating
    
    // 1. Add a flag to track if the task has been started.
    var hasStartedAuthorization = false
    
    let callback: IdpCallback

    enum AuthState {
        case authenticating
        case completed
        case failure(Error)
    }
    
    init(callback: IdpCallback) {
        self.callback = callback
    }
    
    func performAuthorization() async {
        Task { @MainActor in
            // 2. Check the flag. If the task has already run, do nothing.
            guard !hasStartedAuthorization else { return }
            hasStartedAuthorization = true
            
            let result = await callback.authorize()
            
            switch result {
            case .success:
                self.authState = .completed
            case .failure(let error):
                self.authState = .failure(error)
            }

        }
    }
}
