//
//  ApproveDeviceView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import UIKit
import PingOidc
import PingBrowser

// UITextView wrapper that sets inputAccessoryView to an empty zero-frame view,
// silencing the UIKit internal accessoryView/inputView constraint conflict in sheets.
private struct NoAccessoryTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.inputAccessoryView = UIView(frame: .zero)
        tv.backgroundColor = .clear
        tv.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.keyboardType = .URL
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoAccessoryTextView
        init(_ parent: NoAccessoryTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
    }
}

/// Side-channel for handing a verification URL to a navigation destination
/// without going through `@State`/`@Binding` propagation. SwiftUI does not
/// guarantee that two sibling `@State` writes (`pendingVerificationUri` and
/// `path.append`) are coalesced into the same render pass, so the destination
/// view can be constructed before the URL binding is observed by the parent.
@MainActor
enum DeviceApproval {
    static var pendingVerificationUri: URL?
}

struct ApproveDeviceView: View {
    @Binding var path: [MenuItem]

    @State private var verificationUri = ""
    @State private var isAuthorizing = false
    @State private var errorMessage: String? = nil
    @State private var showScanner = false

    private var hasDavinci: Bool { ConfigurationManager.shared.davinci != nil }
    private var hasJourney: Bool { ConfigurationManager.shared.journey != nil }
    private var hasDevice: Bool { ConfigurationManager.shared.deviceClient != nil }
    private var trimmedUri: String { verificationUri.trimmingCharacters(in: .whitespaces) }
    private var isUriEmpty: Bool { trimmedUri.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.themeButtonBackground)

                        Text("Approve on This Device")
                            .font(.system(size: 20, weight: .semibold))

                        Text("Paste the verification URL from another device (including the user_code) and tap Approve to authorize it here.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Verification URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Spacer()

                            Button {
                                showScanner = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.system(size: 14))
                                    Text("Scan")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.themeButtonBackground)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        ZStack(alignment: .topLeading) {
                            if verificationUri.isEmpty {
                                Text("https://…?user_code=XXXX-XXXX")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(Color(.placeholderText))
                                    .allowsHitTesting(false)
                            }
                            NoAccessoryTextView(text: $verificationUri)
                                .frame(minHeight: 72)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(20)
            }

            // Buttons pinned to the bottom
            VStack(spacing: 10) {
                if isAuthorizing {
                    ProgressView("Opening browser…")
                        .padding(.vertical, 8)
                } else {
                    if hasDavinci {
                        approveButton(
                            title: "Approve with DaVinci",
                            icon: "key.fill",
                            style: .primary,
                            action: { approveNative(.davinciDeviceApprove) }
                        )
                    }
                    if hasJourney {
                        approveButton(
                            title: "Approve with Journey",
                            icon: "map.fill",
                            style: .primary,
                            action: { approveNative(.journeyDeviceApprove) }
                        )
                    }
                    if hasDevice {
                        approveButton(
                            title: "Approve in Browser",
                            icon: "safari.fill",
                            style: .secondary,
                            action: authorizeBrowser
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .background(Color(.systemGroupedBackground))
        }
        .background(Color(.systemGroupedBackground))
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Approve Device")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            DeviceQRScannerSheet(verificationUri: $verificationUri)
        }
    }

    private enum ButtonStyleVariant { case primary, secondary }

    @ViewBuilder
    private func approveButton(title: String, icon: String, style: ButtonStyleVariant, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(style == .primary
                ? .white
                : (isUriEmpty ? Color.gray : Color.themeButtonBackground))
            .background(style == .primary
                ? (isUriEmpty ? Color.gray.opacity(0.4) : Color.themeButtonBackground)
                : Color.themeButtonBackground.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isUriEmpty)
    }

    private func approveNative(_ menuItem: MenuItem) {
        errorMessage = nil
        guard let url = URL(string: trimmedUri) else {
            errorMessage = "Invalid verification URL."
            return
        }
        DeviceApproval.pendingVerificationUri = url
        path.append(menuItem)
    }

    private func authorizeBrowser() {
        errorMessage = nil
        guard let client = ConfigurationManager.shared.deviceClient else {
            errorMessage = "No Device Flow configuration found. Add one in Configurations."
            return
        }
        isAuthorizing = true
        let uri = trimmedUri
        Task {
            do {
                try await client.authorize(verificationUriComplete: uri)
            } catch BrowserError.externalUserAgentCancelled {
                // user closed the browser — fall through to pop
            } catch {
                errorMessage = error.localizedDescription
                isAuthorizing = false
                return
            }
            isAuthorizing = false
            path.removeLast()
        }
    }
}
