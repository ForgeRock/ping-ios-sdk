//
//  PingOneMFAOtpView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOneMFA

struct PingOneMFAOtpView: View {
    @Binding var path: [MenuItem]
    @StateObject private var viewModel = PingOneMFAOtpViewModel()

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.otpInfo == nil {
                PingLoadingSpinner()
            } else {
                ScrollView {
                    VStack(spacing: PingTheme.Spacing.large) {
                        otpCard
                    }
                    .pingScrollContentPadding()
                }
            }

            // Loading overlay while refreshing an already-displayed code.
            if viewModel.isLoading && viewModel.otpInfo != nil {
                PingLoadingOverlay()
            }
        }
        .pingScreenBackground()
        .navigationTitle("One-Time Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadOtp()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            PingIconTile(systemName: "number.square.fill", diameter: 80, cornerRadius: PingTheme.Shape.pillRadius, iconSize: 48)

            if let info = viewModel.otpInfo {
                // OTP code — large, prominent, monospaced
                Text(info.code)
                    .font(PingTheme.Typography.code)
                    .foregroundStyle(PingTheme.Color.contentPrimary)
                    .tracking(8)

                // Live countdown
                Text(viewModel.countdown > 0 ? "Refreshes in \(viewModel.countdown)s" : "Expired")
                    .font(PingTheme.Typography.body.weight(.medium))
                    .foregroundStyle(PingTheme.Color.contentSecondary)
            } else if !viewModel.isLoading {
                Text("—")
                    .font(PingTheme.Typography.code)
                    .foregroundStyle(PingTheme.Color.contentSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .pingCardStyle(size: .large)
    }
}
