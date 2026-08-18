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
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading && viewModel.otpInfo == nil {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        otpCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                }
            }

            // Loading overlay while refreshing an already-displayed code.
            if viewModel.isLoading && viewModel.otpInfo != nil {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .navigationTitle("One-Time Passcode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadOtp()
        }
        .onDisappear {
            viewModel.stopRefreshing()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - OTP Card

    private var otpCard: some View {
        VStack(spacing: 24) {
            // Gradient icon
            Image(systemName: "number.square.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(
                    LinearGradient(
                        colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if let info = viewModel.otpInfo {
                // OTP code — large, prominent, monospaced
                Text(info.code)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                    .tracking(8)

                // Live countdown
                Text(viewModel.countdown > 0 ? "Refreshes in \(viewModel.countdown)s" : "Expired")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            } else if !viewModel.isLoading {
                Text("—")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }
}
