//
//  PingOneMFADavinciAuthenticationView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci
import PingOneMFA
import PingOrchestrate

struct PingOneMFADavinciAuthenticationView: View {
    @Binding var path: [MenuItem]
    @StateObject private var davinciViewModel = DavinciViewModel()
    @StateObject private var validationViewModel = ValidationViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    switch davinciViewModel.state.node {
                    case let continueNode as ContinueNode:
                        authenticationStep(continueNode)
                    case let failureNode as FailureNode:
                        let apiError = failureNode.cause as? ApiError
                        switch apiError {
                        case .error(_, _, let message):
                            ErrorView(title: "DaVinci Authentication Error", message: message)
                        default:
                            ErrorView(title: "DaVinci Authentication Error", message: "unknown error")
                        }
                    case let errorNode as ErrorNode:
                        ErrorNodeView(node: errorNode)
                        if let nextNode = errorNode.continueNode {
                            authenticationStep(nextNode)
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            if davinciViewModel.isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2)
                    .tint(.themeButtonBackground)
            }
        }
        .navigationTitle("DaVinci Authentication")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func authenticationStep(_ node: ContinueNode) -> some View {
        VStack(spacing: 16) {
            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
            ContinueNodeView(
                continueNode: node,
                onNodeUpdated: { davinciViewModel.refresh() },
                onStart: { Task { await davinciViewModel.startDavinci() } },
                onNext: { isSubmit in
                    Task { await handleNext(node: node, isSubmit: isSubmit) }
                },
                metadataViewBuilder: { field, onNext in
                    AnyView(PingOneMFADavinciAuthenticationMetadataView(field: field, onNext: onNext))
                }
            )
            .environmentObject(validationViewModel)
        }
    }

    private func handleNext(node: ContinueNode, isSubmit: Bool) async {
        validationViewModel.shouldValidate = isSubmit
            && davinciViewModel.shouldValidate(node: node)
        guard !validationViewModel.shouldValidate else { return }

        await davinciViewModel.next(node: node)
    }
}

struct PingOneMFADavinciAuthenticationMetadataView: View {
    let field: MetadataCollector
    let onNext: (Bool) -> Void

    @State private var isSubmitting = false

    private var isMobilePayloadRequest: Bool {
        (field.metadata["sdk"] as? String) == "MFA"
            && (field.metadata["action"] as? String) == "MOBILE_PAYLOAD"
    }

    private var prettyMetadata: String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: field.metadata,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SDK Metadata")
                .font(.headline)

            Text("Payload from DaVinci:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(prettyMetadata)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 240)

            if isMobilePayloadRequest {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Collecting mobile payload…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .task {
                    await collectMobilePayload()
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Validating mobile authentication…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .task {
                    submitAuthenticationResult()
                }
            }
        }
        .padding()
    }

    private func collectMobilePayload() async {
        guard !isSubmitting else { return }
        isSubmitting = true

        do {
            if !ConfigurationManager.shared.isPingOneMFAInitialized {
                try await ConfigurationManager.shared.initializePingOneMFAClient()
            }
            let payload = try await PingOneMFA.generateMobilePayload()
            isSubmitting = false
            field.setResult(["mobilePayload": payload])
        } catch {
            isSubmitting = false
            field.setError(code: "MOBILE_PAYLOAD_FAILED", message: error.localizedDescription)
        }

        onNext(true)
    }

    private func submitAuthenticationResult() {
        guard !isSubmitting else { return }
        isSubmitting = true

        guard let status = field.metadata["status"] as? String else {
            submitError(
                code: "MOBILE_AUTHENTICATION_INVALID_RESPONSE",
                message: "The mobile authentication response does not contain a status."
            )
            return
        }

        guard status == "COMPLETED" else {
            submitError(
                code: "MOBILE_AUTHENTICATION_NOT_COMPLETED",
                message: "The mobile authentication status is \(status)."
            )
            return
        }

        guard let authenticators = field.metadata["authenticators"] as? [String] else {
            submitError(
                code: "MOBILE_AUTHENTICATION_INVALID_RESPONSE",
                message: "The mobile authentication response does not contain authenticators."
            )
            return
        }

        guard authenticators.contains("swk"), authenticators.contains("mfa") else {
            submitError(
                code: "MOBILE_AUTHENTICATION_MISSING_AUTHENTICATOR",
                message: "The mobile authentication response must include swk and mfa authenticators."
            )
            return
        }
        
        isSubmitting = false
        field.setResult(["success": true])
        onNext(true)
    }

    private func submitError(code: String, message: String) {
        isSubmitting = false
        field.setError(code: code, message: message)
        onNext(true)
    }
}
