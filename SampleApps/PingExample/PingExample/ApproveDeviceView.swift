//
//  ApproveDeviceView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
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
                VStack(spacing: PingTheme.Spacing.large) {
                    VStack(spacing: PingTheme.Spacing.small) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: PingTheme.Control.Glyph.hero))
                            .foregroundStyle(PingTheme.Color.actionPrimary)

                        Text("Approve on This Device")
                            .pingScreenTitle()

                        Text("Paste the verification URL from another device (including the user_code) and tap Approve to authorize it here.")
                            .pingSupportingText()
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
                        HStack {
                            Text("Verification URL")
                                .pingCaptionText()
                                .textCase(.uppercase)

                            Spacer()

                            Button {
                                showScanner = true
                            } label: {
                                HStack(spacing: PingTheme.Spacing.xSmall) {
                                    Image(systemName: "qrcode.viewfinder")
                                    Text("Scan")
                                }
                                .font(PingTheme.Typography.caption)
                                .foregroundStyle(PingTheme.Color.actionPrimary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        ZStack(alignment: .topLeading) {
                            if verificationUri.isEmpty {
                                Text("https://…?user_code=XXXX-XXXX")
                                    .font(PingTheme.Typography.supporting.monospaced())
                                    .foregroundStyle(PingTheme.Color.contentTertiary)
                                    .allowsHitTesting(false)
                            }
                            NoAccessoryTextView(text: $verificationUri)
                                .frame(minHeight: 72)
                        }
                        .pingTextFieldStyle()
                    }

                    if let error = errorMessage {
                        HStack(spacing: PingTheme.Spacing.small) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(PingTheme.Color.statusError)
                            Text(error)
                                .font(PingTheme.Typography.supporting)
                                .foregroundStyle(PingTheme.Color.contentPrimary)
                        }
                        .pingStatusCardStyle(tint: PingTheme.Color.statusError)
                    }
                }
                .padding(PingTheme.Spacing.screen)
            }

            // Buttons pinned to the bottom
            VStack(spacing: PingTheme.Spacing.small) {
                if isAuthorizing {
                    ProgressView("Opening browser…")
                        .padding(.vertical, PingTheme.Spacing.small)
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
            .padding(.horizontal, PingTheme.Spacing.screen)
            .padding(.top, bottomBarTopPadding)
            .padding(.bottom, bottomBarBottomPadding)
            .background(PingTheme.Color.appBackground)
        }
        .pingScreenBackground()
        .ignoresSafeArea(.keyboard)
        .navigationTitle("Approve Device")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            DeviceQRScannerSheet(verificationUri: $verificationUri)
        }
    }

    /// Framing padding for the bottom action bar. No shared token matches these values.
    private let bottomBarTopPadding: CGFloat = 12
    private let bottomBarBottomPadding: CGFloat = 24

    private enum ButtonStyleVariant { case primary, secondary }

    @ViewBuilder
    private func approveButton(title: String, icon: String, style: ButtonStyleVariant, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: PingTheme.Spacing.small) {
                Image(systemName: icon)
                Text(title)
            }
        }
        .buttonStyle(PingActionButtonStyle(role: style == .primary ? .primary : .secondary))
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
