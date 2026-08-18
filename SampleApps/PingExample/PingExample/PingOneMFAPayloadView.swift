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
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        payloadCard
                        copyButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Mobile Payload")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPayload()
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

    // MARK: - Payload Card

    private var payloadCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(
                            colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Payload")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            Divider()

            if let payload = viewModel.payload {
                Text(payload)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("No payload available.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Copy Button

    private var copyButton: some View {
        Button {
            if let payload = viewModel.payload {
                UIPasteboard.general.string = payload
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 16))
                Text("Copy")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                viewModel.payload != nil
                    ? LinearGradient(
                        colors: [.themeButtonBackground, Color(red: 0.6, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    : LinearGradient(
                        colors: [Color.gray, Color.gray],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.payload == nil)
        .accessibilityIdentifier("copyPayloadButton")
    }
}
