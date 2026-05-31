//
//  DeviceQRScannerSheet.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI

struct DeviceQRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var verificationUri: String
    @State private var scannerDelegate: ScannerDelegate?

    @MainActor
    final class ScannerDelegate: NSObject, QRScannerDelegate {
        let onScan: @MainActor (String) -> Void
        init(onScan: @escaping @MainActor (String) -> Void) { self.onScan = onScan }
        nonisolated func didScan(code: String) {
            Task { @MainActor [weak self] in self?.onScan(code) }
        }
        nonisolated func didFailWithError(error: Error) {}
    }

    var body: some View {
        NavigationStack {
            QRScannerView(delegate: scannerDelegate)
                .ignoresSafeArea()
                .navigationTitle("Scan Verification QR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .onAppear {
                    if scannerDelegate == nil {
                        scannerDelegate = ScannerDelegate { code in
                            verificationUri = code
                            dismiss()
                        }
                    }
                }
        }
    }
}
