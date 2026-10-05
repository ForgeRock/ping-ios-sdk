//
//  QRCodeView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci

/// A display-only view that renders the QR code provided by a `QRCodeCollector`.
///
/// The collector carries image data decoded from a data URI sent by the server.
/// This view converts it to a `UIImage` and displays it centred within the form.
/// If the image data is absent or invalid a placeholder icon is shown instead.
/// A `fallbackText` (e.g. a URL or manual entry code) is shown below the image
/// when provided by the server, matching the Android `QRCode` composable.
struct QRCodeView: View {
    let collector: QRCodeCollector

    var body: some View {
        VStack(spacing: PingTheme.Spacing.compact) {
            if let imageData = collector.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 240)
                    .accessibilityLabel("QR Code")
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundStyle(PingTheme.Color.contentSecondary)
                Text("QR code unavailable")
                    .pingCaptionText()
            }

            if !collector.fallbackText.isEmpty {
                Text(collector.fallbackText)
                    .pingCaptionText()
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
