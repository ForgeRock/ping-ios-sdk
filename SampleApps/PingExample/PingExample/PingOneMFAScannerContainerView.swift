//
//  PingOneMFAScannerContainerView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
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
                VStack(spacing: 12) {
                    TextField("Enter pairing key manually", text: $manualKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isTextFieldFocused)

                    Button {
                        let key = manualKey.trimmingCharacters(in: .whitespaces)
                        guard !key.isEmpty else { return }
                        isTextFieldFocused = false
                        Task { await viewModel.handleScannedCode(key) }
                    } label: {
                        Text("Pair")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualKey.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isLoading)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.bottom, 16)
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
