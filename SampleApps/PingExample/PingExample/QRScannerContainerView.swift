//
//  QRScannerContainerView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

/// Container View for QR Scanner functionality with alert handling.
/// Uses `QRScannerViewModel` to manage scanning state and results.
struct QRScannerContainerView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = QRScannerViewModel()
    @State private var scannerDelegate: ScannerDelegate?
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ZStack {
            QRScannerView(delegate: scannerDelegate)
                .ignoresSafeArea()

            VStack {
                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .padding(.bottom, 50)
                }
            }
        }
        .navigationTitle("QR Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if scannerDelegate == nil {
                scannerDelegate = ScannerDelegate(viewModel: viewModel)
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
    }
}

@MainActor
class ScannerDelegate: NSObject, QRScannerDelegate {
    let viewModel: QRScannerViewModel

    init(viewModel: QRScannerViewModel) {
        self.viewModel = viewModel
    }

    nonisolated func didScan(code: String) {
        print("ScannerDelegate: Received scanned code")
        Task { @MainActor in
            await viewModel.handleScannedCode(code)
        }
    }

    nonisolated func didFailWithError(error: Error) {
        print("ScannerDelegate: Received error: \(error)")
        Task { @MainActor in
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
