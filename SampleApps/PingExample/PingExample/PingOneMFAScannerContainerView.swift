//
//  PingOneMFAScannerContainerView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI


struct PingOneMFAScannerContainerView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PingOneMFAScannerViewModel()
    @State private var scannerDelegate: PingOneMFAScannerDelegate?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var manualKey = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            QRScannerView(delegate: scannerDelegate)
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Manual pairing key entry
                VStack(spacing: PingTheme.Spacing.small) {
                    TextField("Enter pairing key manually", text: $manualKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isTextFieldFocused)
                        .pingTextFieldStyle()

                    Button {
                        let key = manualKey.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        isTextFieldFocused = false
                        Task { await viewModel.handleScannedCode(key) }
                    } label: {
                        Text("Pair")
                    }
                    .buttonStyle(.pingPrimary)
                    .disabled(manualKey.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
                .padding(.horizontal, PingTheme.Spacing.screen)
                .padding(.bottom, PingTheme.Spacing.scrollBottomInset)

                if viewModel.isLoading {
                    PingLoadingSpinner(tint: PingTheme.Color.contentInverse)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.cardRadius))
                        .padding(.bottom, PingTheme.Spacing.medium)
                }
            }
        }
        .navigationTitle("PingOne MFA Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if scannerDelegate == nil {
                scannerDelegate = PingOneMFAScannerDelegate(viewModel: viewModel)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if viewModel.registrationSuccess {
                    path.removeLast()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: viewModel.errorMessage) { newValue in
            if let error = newValue {
                alertTitle = "Error"
                alertMessage = error
                showAlert = true
            }
        }
        .onChange(of: viewModel.successMessage) { newValue in
            if let success = newValue {
                alertTitle = "Success"
                alertMessage = success
                showAlert = true
            }
        }
        .onChange(of: viewModel.registrationSuccess) { success in
            if success { manualKey = "" }
        }
    }
}

/// Delegate that bridges `QRScannerDelegate` callbacks to `PingOneMFAScannerViewModel`.
/// Defined in the same file to avoid modifying the shared `ScannerDelegate` class.
@MainActor
class PingOneMFAScannerDelegate: NSObject, QRScannerDelegate {
    let viewModel: PingOneMFAScannerViewModel

    init(viewModel: PingOneMFAScannerViewModel) {
        self.viewModel = viewModel
    }

    nonisolated func didScan(code: String) {
        Task { @MainActor in
            await viewModel.handleScannedCode(code)
        }
    }

    nonisolated func didFailWithError(error: Error) {
        Task { @MainActor in
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
