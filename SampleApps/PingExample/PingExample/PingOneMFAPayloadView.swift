//
//  PingOneMFAPayloadView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import UIKit
import PingOneMFA

struct PingOneMFAPayloadView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PingOneMFAPayloadViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                PingLoadingSpinner()
            } else {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        payloadCard
                        copyButton
                    }
                    .pingScrollContentPadding()
                }
            }
        }
        .pingScreenBackground()
        .navigationTitle("Mobile Payload")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPayload()
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    // MARK: - Payload Card

    private var payloadCard: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            HStack(spacing: PingTheme.Spacing.medium) {
                PingIconTile(systemName: "doc.badge.gearshape.fill", diameter: 40, iconSize: 20)

                Text("Payload")
                    .pingSectionHeader()

                Spacer()
            }

            Divider()

            if let payload = viewModel.payload {
                Text(payload)
                    .font(PingTheme.Typography.monospacedCaption)
                    .foregroundStyle(PingTheme.Color.contentPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No payload available.")
                    .pingSupportingText()
            }
        }
        .pingCardStyle()
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            if let payload = viewModel.payload {
                UIPasteboard.general.string = payload
            }
        } label: {
            HStack(spacing: PingTheme.Spacing.small) {
                Image(systemName: "doc.on.doc")
                Text("Copy")
            }
        }
        .buttonStyle(.pingPrimary)
        .disabled(viewModel.payload == nil)
        .accessibilityIdentifier("copyPayloadButton")
    }
}
