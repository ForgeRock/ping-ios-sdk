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
    /// Set to `true` after a successful approve or deny so the view can dismiss.
    @Published var shouldDismiss: Bool = false

    init(notification: PushNotification) {
        self.notification = notification
    }

    /// Approves the authentication request with an optional number-matching challenge.
    func approve(numberChallenge: Int? = nil) {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                try await notification.approve(authMethod: "user", numberChallenge: numberChallenge)
                shouldDismiss = true
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
                try await notification.deny()
                shouldDismiss = true
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
/// Supports three layouts based on `notification.numberMatchingType`:
/// - `"SELECT_NUMBER"`: displays tappable number buttons from `notification.numberMatchingOptions`.
/// - `"ENTER_MANUALLY"` (or any other non-empty type): displays a `.numberPad` text field.
/// - `""` (empty): displays plain Approve / Deny buttons with no number-matching UI.
struct PingOneMFANotificationView: View {
    @StateObject private var viewModel: PingOneMFANotificationViewModel
    @Environment(\.dismiss) private var dismiss

    /// Text entry state for the ENTER_MANUALLY path.
    @State private var enteredText: String = ""

    init(notification: PushNotification) {
        _viewModel = StateObject(wrappedValue: PingOneMFANotificationViewModel(notification: notification))
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            header

            // Title / Message
            notificationContent

            // Number-matching UI (conditional)
            if viewModel.notification.numberMatchingType == "SELECT_NUMBER" {
                selectNumberSection
            } else if !viewModel.notification.numberMatchingType.isEmpty {
                enterManuallySection
            }

            // Error message (if any)
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Plain Approve / Deny buttons (always shown)
            actionButtons

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .padding()
        .onChange(of: viewModel.shouldDismiss) { shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "bell.badge.fill")
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

            VStack(alignment: .leading, spacing: 2) {
                Text("PingOne MFA Authentication")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Approve or deny this request")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = viewModel.notification.title {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let message = viewModel.notification.message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// SELECT_NUMBER path: tappable number buttons, one per option.
    private var selectNumberSection: some View {
        VStack(spacing: 16) {
            Text("Select the number shown on your other device")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            let options = viewModel.notification.numberMatchingOptions
            if options.isEmpty {
                Text("No options available")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            } else {
                HStack(spacing: 16) {
                    ForEach(options, id: \.self) { number in
                        Button {
                            viewModel.approve(numberChallenge: number)
                        } label: {
                            Text("\(number)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.themeButtonBackground)
                                .frame(width: 80, height: 80)
                                .background(Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(Color.themeButtonBackground, lineWidth: 2)
                                )
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
        }
    }

    /// ENTER_MANUALLY (or any non-empty non-SELECT_NUMBER) path: numeric text field.
    private var enterManuallySection: some View {
        VStack(spacing: 12) {
            Text("Enter the number shown on your other device")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextField("Number", text: $enteredText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 20, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 160)

            Button {
                if let number = Int(enteredText) {
                    viewModel.approve(numberChallenge: number)
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirm Number")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(enteredText.isEmpty || Int(enteredText) == nil ? Color.gray : Color.green)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(enteredText.isEmpty || Int(enteredText) == nil || viewModel.isLoading)
        }
    }

    /// Approve (green) and Deny (red) action buttons — always shown.
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Deny button
            Button {
                viewModel.deny()
            } label: {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Deny")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.isLoading)

            // Approve button (only shown when no number-matching UI is active)
            if viewModel.notification.numberMatchingType.isEmpty {
                Button {
                    viewModel.approve()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}
