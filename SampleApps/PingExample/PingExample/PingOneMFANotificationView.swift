//
//  PingOneMFANotificationView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingOneMFA

// MARK: - ViewModel

/// ViewModel backing `PingOneMFANotificationView`. Holds the notification value and async call state.
@MainActor
final class PingOneMFANotificationViewModel: ObservableObject {
    let notification: PushNotification

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showSuccessAlert: Bool = false
    @Published var isDenied: Bool = false

    init(notification: PushNotification) {
        self.notification = notification
    }

    /// Approves the authentication request with an optional number-matching challenge.
    func approve(numberChallenge: Int? = nil) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await notification.approveNotification(authMethod: "user", numberChallenge: numberChallenge)
                showSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Denies the authentication request.
    func deny() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await notification.denyNotification()
                isDenied = true
                showSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

// MARK: - View

/// A modal sheet that presents a PingOneMFA push notification and lets the user approve or deny it.
///
/// Supports three layouts based on `notification.pushType`:
/// - `.challenge` with non-empty `getNumbersChallenge`: displays tappable number buttons.
/// - `.challenge` with empty `getNumbersChallenge`: displays a `.numberPad` text field.
/// - `.default`: displays plain Approve / Deny buttons with no number-matching UI.
struct PingOneMFANotificationView: View {
    @StateObject private var viewModel: PingOneMFANotificationViewModel
    @Environment(\.dismiss) private var dismiss

    /// Text entry state for the ENTER_MANUALLY path.
    @State private var enteredText: String = ""

    init(notification: PushNotification) {
        _viewModel = StateObject(wrappedValue: PingOneMFANotificationViewModel(notification: notification))
    }

    var body: some View {
        VStack(spacing: PingTheme.Spacing.large) {
            // Header
            header

            // Title / Message
            notificationContent

            // Number-matching UI (conditional)
            if viewModel.notification.pushType == .challenge {
                if !viewModel.notification.getNumbersChallenge.isEmpty {
                    selectNumberSection
                } else {
                    enterManuallySection
                }
            }

            // Buttons or loading indicator
            if viewModel.isLoading {
                loadingIndicator
            } else {
                actionButtons
            }

            Spacer()
        }
        .padding(PingTheme.Spacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pingScreenBackground()
        .onAppear {
            if viewModel.notification.isCancelAuthentication {
                dismiss()
            }
        }
        .alert(viewModel.isDenied ? "Denied" : "Approved", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.isDenied ? "Authentication denied successfully" : "Authentication approved successfully")
        }
        .pingErrorAlert(errorMessage: $viewModel.errorMessage)
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            PingIconTile(systemName: "bell.badge.fill", diameter: 40, iconSize: 20)

            VStack(alignment: .leading, spacing: PingTheme.Spacing.xxSmall) {
                Text("PingOne MFA Authentication")
                    .pingSectionHeader()

                Text("Approve or deny this request")
                    .pingSupportingText()
            }

            Spacer()
        }
    }

    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: PingTheme.Spacing.small) {
            if let title = viewModel.notification.title {
                Text(title)
                    .font(PingTheme.Typography.body.weight(.medium))
                    .foregroundStyle(PingTheme.Color.contentPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let message = viewModel.notification.message {
                Text(message)
                    .pingSupportingText()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// SELECT_NUMBER path: tappable number buttons, one per option.
    private var selectNumberSection: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            Text("Select the number shown on your other device")
                .pingBodySecondary()
                .multilineTextAlignment(.center)

            let options = viewModel.notification.getNumbersChallenge
            if options.isEmpty {
                Text("No options available")
                    .font(PingTheme.Typography.supporting)
                    .foregroundStyle(PingTheme.Color.statusError)
            } else {
                HStack(spacing: PingTheme.Spacing.medium) {
                    ForEach(options, id: \.self) { number in
                        PingChallengeNumberButton(number: number) {
                            viewModel.approve(numberChallenge: number)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
    }

    /// ENTER_MANUALLY (or any non-empty non-SELECT_NUMBER) path: numeric text field.
    private var enterManuallySection: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            Text("Enter the number shown on your other device")
                .pingBodySecondary()
                .multilineTextAlignment(.center)
            
            TextField("Number", text: $enteredText)
                .keyboardType(.numberPad)
                .pingTextFieldStyle()
                .font(PingTheme.Typography.screenTitle.monospaced())
                .multilineTextAlignment(.center)
                .frame(maxWidth: 160)
            
            if !viewModel.isLoading {
                Button {
                    if let number = Int(enteredText) {
                        viewModel.approve(numberChallenge: number)
                    }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirm Number")
                    }
                }
                .buttonStyle(.pingAffirmative)
                .disabled(enteredText.isEmpty || Int(enteredText) == nil)
            }
        }
    }

    private var loadingIndicator: some View {
        PingLoadingSpinner()
            .frame(maxWidth: .infinity)
            .padding(.vertical, PingTheme.Spacing.medium)
    }

    /// Approve and Deny action buttons — always shown.
    private var actionButtons: some View {
        HStack(spacing: PingTheme.Spacing.medium) {
            // Deny button
            Button {
                viewModel.deny()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Deny")
                }
            }
            .buttonStyle(.pingDestructive)

            // Approve button (only shown when no number-matching UI is active)
            if viewModel.notification.pushType == .default {
                Button {
                    viewModel.approve()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                    }
                }
                .buttonStyle(.pingAffirmative)
            }
        }
    }
}
