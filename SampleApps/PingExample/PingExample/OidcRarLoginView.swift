//
//  OidcRarLoginView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//


import Foundation
import SwiftUI
import PingOidc
import PingOrchestrate

/// Screen for exercising RFC 9396 Rich Authorization Requests on the OIDC (Web) flow:
/// paste authorization_details JSON, run the login with it (per-transaction), with PAR
/// on or off, and see the granted details on the token screen.
struct OidcRarLoginView: View {
    @StateObject private var viewModel = OidcRarLoginViewModel()
    @Binding var path: [MenuItem]
    @State private var preset: RarPreset = .paymentInitiation

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    statusCard
                    presetPicker
                    jsonEditor
                    loginButton
                    switch viewModel.state {
                    case .success:
                        // A real (empty) container view, NOT EmptyView: EmptyView produces
                        // nothing in the hierarchy so its onAppear never fires, and the
                        // navigation to the token screen would never happen.
                        VStack {}.onAppear {
                            path.removeLast()
                            path.append(.oidcToken)
                            // Reset so returning to this screen doesn't immediately bounce back.
                            viewModel.reset()
                        }
                    case .failure(let error):
                        ErrorView(title: "OIDC Error", message: error.localizedDescription)
                    case .none:
                        EmptyView()
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("OIDC RAR Login")
    }

    // MARK: - Sections

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.selectedConfig?.name ?? "No OIDC (Web) configuration selected")
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 16) {
                Label(viewModel.parEnabled ? "PAR: on" : "PAR: off", systemImage: "arrow.up.forward.square")
                    .foregroundStyle(viewModel.parEnabled ? Color(.systemGreen) : Color(.systemGray))
                Label(viewModel.configLevelDetailsSet ? "Config details: set" : "Config details: not set",
                      systemImage: "doc.text.magnifyingglass")
                    .foregroundStyle(viewModel.configLevelDetailsSet ? Color(.systemGreen) : Color(.systemGray))
            }
            .font(.system(size: 12))
            Text("Per-transaction details below win over config-level details for this login. PAR toggling rebuilds the client (config-level flag).")
                .font(.system(size: 11))
                .foregroundStyle(Color(.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var presetPicker: some View {
        TabPicker(selection: $preset, label: { $0.rawValue }, icon: { _ in "doc.text" }) { tab in
            viewModel.jsonText = tab.json
            _ = viewModel.validate()
        }
    }

    private var jsonEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("authorization_details (JSON array)")
                .font(.system(size: 13, weight: .semibold))
            TextEditor(text: $viewModel.jsonText)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 180)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemGroupedBackground)))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.jsonText) { _ in
                    _ = viewModel.validate()
                }
            if let error = viewModel.validationError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.systemRed))
            } else {
                Text("Valid — \(jsonObjectCount) object(s). Sent in the PAR body when PAR is on, otherwise on the authorize URL.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(.systemGreen))
            }
        }
    }

    private var jsonObjectCount: Int {
        viewModel.decodedDetails()?.count ?? 0
    }

    private var loginButton: some View {
        Button {
            if let details = viewModel.validate() {
                viewModel.login(details: details)
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.shield")
                }
                Text("Login with authorization_details")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.decodedDetails() == nil || viewModel.isLoading)
    }
}
