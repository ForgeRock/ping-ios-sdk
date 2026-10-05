//
//  PingOneMFADavinciAuthorizationView.swift
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

struct PingOneMFADavinciAuthorizationView: View {
    @StateObject private var davinciViewModel = DavinciViewModel()
    @StateObject private var validationViewModel = ValidationViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    switch davinciViewModel.state.node {
                    case let continueNode as ContinueNode:
                        authenticationStep(continueNode)
                    case is SuccessNode:
                        Label("DaVinci Authorization complete", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .padding()
                    case let failureNode as FailureNode:
                        let apiError = failureNode.cause as? ApiError
                        switch apiError {
                        case .error(_, _, let message):
                            ErrorView(title: "DaVinci Authorization Error", message: message)
                        default:
                            ErrorView(title: "DaVinci Authorization Error", message: "unknown error")
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
                    .tint(PingTheme.Color.actionPrimary)
            }
        }
        .navigationTitle("DaVinci Authorization")
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
                    // Only METADATA steps owned by this flow get the custom view; any other
                    // METADATA collector (e.g. PROTECT/INITIALIZE) keeps the default behavior.
                    guard PingOneMFADavinciAuthenticationMetadataView.handles(field) else {
                        return AnyView(MetadataView(field: field, onNext: onNext))
                    }
                    return AnyView(
                        PingOneMFADavinciAuthenticationMetadataView(
                            field: field,
                            onNext: onNext
                        )
                    )
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
    @State private var authenticationValidationState: AuthenticationValidationState = .validating

    private enum AuthenticationValidationState {
        case validating
        case validated
        case failed
    }

    /// Whether this view owns the given METADATA step: the `MFA`/`MOBILE_PAYLOAD` request, or the
    /// device-authentication result, which the flow delivers wrapped in a `rawResponse` object.
    static func handles(_ field: MetadataCollector) -> Bool {
        isMobilePayloadRequest(field.metadata) || field.metadata["rawResponse"] is [String: Any]
    }

    private static func isMobilePayloadRequest(_ metadata: [String: Any]) -> Bool {
        (metadata["sdk"] as? String) == "MFA"
            && (metadata["action"] as? String) == "MOBILE_PAYLOAD"
    }

    var body: some View {
        Group {
            if Self.isMobilePayloadRequest(field.metadata) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Collecting mobile payload…")
                        .foregroundStyle(.secondary)
                }
                .task {
                    await collectMobilePayload()
                }
            } else {
                authenticationValidationStatus
                    .task {
                        submitAuthenticationResult()
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private var authenticationValidationStatus: some View {
        switch authenticationValidationState {
        case .validating:
            HStack(spacing: 8) {
                ProgressView()
                Text("Validating mobile authentication…")
                    .foregroundStyle(.secondary)
            }
        case .validated:
            Label("Mobile authentication validated", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("Failed to validate mobile authentication", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
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

        guard let rawResponse = field.metadata["rawResponse"] as? [String: Any] else {
            submitError(
                code: "MOBILE_AUTHENTICATION_INVALID_RESPONSE",
                message: "The mobile authentication response does not contain a rawResponse."
            )
            return
        }

        guard let status = rawResponse["status"] as? String else {
            submitError(
                code: "MOBILE_AUTHENTICATION_INVALID_RESPONSE",
                message: "The mobile authentication rawResponse does not contain a status."
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

        guard let authenticators = rawResponse["authenticators"] as? [String] else {
            submitError(
                code: "MOBILE_AUTHENTICATION_INVALID_RESPONSE",
                message: "The mobile authentication rawResponse does not contain authenticators."
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
        authenticationValidationState = .validated
    }

    private func submitError(code: String, message: String) {
        isSubmitting = false
        field.setError(code: code, message: message)
        authenticationValidationState = .failed
    }
}
