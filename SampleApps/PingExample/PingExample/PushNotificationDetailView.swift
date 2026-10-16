// 
//  PushNotificationDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// View to display details of a push notification.
struct PushNotificationDetailView: View {
    @Environment(\.dismiss) var dismiss
    let notification: PushNotification
    let credential: PushCredential?
    
    @State private var showExportSheet = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: PingTheme.Spacing.large) {
                headerSection

                statusSection

                if credential != nil {
                    credentialSection
                }

                notificationInfoSection

                Spacer()

                ExportButton {
                    showExportSheet = true
                }

                DeleteButton {
                    showDeleteAlert = true
                }
            }
            .pingScrollContentPadding()
        }
        .pingScreenBackground()
        .navigationTitle("Notification Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            JsonExportView(title: "Push Notification JSON", jsonData: notificationToJson())
        }
        .alert("Delete Notification", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteNotification()
                }
            }
        } message: {
            Text("Are you sure you want to delete this notification? This action cannot be undone.")
        }
        .pingErrorAlert(errorMessage: $errorMessage)
    }

    private var headerSection: some View {
        VStack(spacing: PingTheme.Spacing.medium) {
            PingIconTile(systemName: typeIcon, diameter: 100, iconSize: 50, shape: .circle)

            Text(statusText)
                .font(PingTheme.Typography.screenTitle.weight(.bold))
                .foregroundStyle(statusColor)

            if let message = notification.messageText {
                Text(message)
                    .pingBodySecondary()
                    .multilineTextAlignment(.center)
            }
        }
        .padding(PingTheme.Spacing.medium)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Status")
                .pingScreenTitle()
                .padding(.bottom, PingTheme.Spacing.medium)

            PingInfoRow(label: "Type", value: notification.pushType.rawValue.uppercased(), labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Status", value: statusText, labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Approved", value: notification.approved ? "Yes" : "No", labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Pending", value: notification.pending ? "Yes" : "No", labelWidth: 90)

            if notification.isExpired {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Expired", value: "Yes", labelWidth: 90)
            }
        }
        .pingCardStyle()
    }

    private var credentialSection: some View {
        Group {
            if let cred = credential {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Associated Account")
                        .pingScreenTitle()
                        .padding(.bottom, PingTheme.Spacing.medium)

                    PingInfoRow(label: "Issuer", value: cred.issuer, labelWidth: 90)
                    Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

                    PingInfoRow(label: "Display Issuer", value: cred.displayIssuer, labelWidth: 90)
                    Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

                    PingInfoRow(label: "Account", value: cred.accountName, labelWidth: 90)
                    Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

                    PingInfoRow(label: "Display Account", value: cred.displayAccountName, labelWidth: 90)
                }
                .pingCardStyle()
            }
        }
    }

    private var notificationInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notification Information")
                .pingScreenTitle()
                .padding(.bottom, PingTheme.Spacing.medium)

            PingInfoRow(label: "ID", value: notification.id, labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Message ID", value: notification.messageId, labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "TTL", value: "\(notification.ttl) seconds", labelWidth: 90)
            Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)

            PingInfoRow(label: "Created", value: formatDate(notification.createdAt), labelWidth: 90)

            if let sentAt = notification.sentAt {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Sent", value: formatDate(sentAt), labelWidth: 90)
            }

            if let respondedAt = notification.respondedAt {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Responded", value: formatDate(respondedAt), labelWidth: 90)
            }

            if let challenge = notification.challenge {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Challenge", value: challenge, labelWidth: 90)
            }

            if let numbersChallenge = notification.numbersChallenge {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Numbers", value: numbersChallenge, labelWidth: 90)
            }

            if let contextInfo = notification.contextInfo {
                Divider().padding(.leading, PingTheme.Control.infoRowDividerInset)
                PingInfoRow(label: "Context", value: contextInfo, labelWidth: 90)
            }
        }
        .pingCardStyle()
    }
    
    private var statusText: String {
        if notification.approved {
            return "Approved"
        } else if notification.isExpired && notification.pending {
            return "Expired"
        } else if notification.pending {
            return "Pending"
        } else {
            return "Denied"
        }
    }
    
    private var statusColor: Color {
        if notification.approved {
            return PingTheme.Color.statusSuccess
        } else if notification.isExpired && notification.pending {
            return PingTheme.Color.statusWarning
        } else if notification.pending {
            return PingTheme.Color.statusInfo
        } else {
            return PingTheme.Color.statusError
        }
    }
    
    private var typeIcon: String {
        switch notification.pushType {
        case .default: return "hand.tap.fill"
        case .biometric: return "faceid"
        case .challenge: return "number.circle.fill"
        @unknown default: return "hand.tap.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func notificationToJson() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(notification)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\n  \"error\": \"Failed to encode notification\"\n}"
        }
    }
    
    private func deleteNotification() async {
        // Note: Notification deletion is typically handled through storage layer
        // For now, just dismiss the view as notifications are transient
        // and will be cleaned up automatically based on retention policy
        dismiss()
    }
}
