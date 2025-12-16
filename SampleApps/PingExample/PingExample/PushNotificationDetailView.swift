// 
//  PushNotificationDetailView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
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
            VStack(spacing: 24) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
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
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: typeIcon)
                .font(.system(size: 50))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(
                    LinearGradient(
                        colors: [statusColor, statusColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())

            Text(statusText)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            if let message = notification.messageText {
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Status")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            NotificationInfoRow(label: "Type", value: notification.pushType.rawValue.uppercased())
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "Status", value: statusText)
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "Approved", value: notification.approved ? "Yes" : "No")
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "Pending", value: notification.pending ? "Yes" : "No")
            
            if notification.isExpired {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Expired", value: "Yes")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var credentialSection: some View {
        Group {
            if let cred = credential {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Associated Account")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.bottom, 16)

                    NotificationInfoRow(label: "Issuer", value: cred.issuer)
                    Divider().padding(.leading, 100)

                    NotificationInfoRow(label: "Display Issuer", value: cred.displayIssuer)
                    Divider().padding(.leading, 100)
                    
                    NotificationInfoRow(label: "Account", value: cred.accountName)
                    Divider().padding(.leading, 100)

                    NotificationInfoRow(label: "Display Account", value: cred.displayAccountName)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var notificationInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Notification Information")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 16)

            NotificationInfoRow(label: "ID", value: notification.id)
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "Message ID", value: notification.messageId)
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "TTL", value: "\(notification.ttl) seconds")
            Divider().padding(.leading, 100)

            NotificationInfoRow(label: "Created", value: formatDate(notification.createdAt))
            
            if let sentAt = notification.sentAt {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Sent", value: formatDate(sentAt))
            }
            
            if let respondedAt = notification.respondedAt {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Responded", value: formatDate(respondedAt))
            }
            
            if let challenge = notification.challenge {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Challenge", value: challenge)
            }
            
            if let numbersChallenge = notification.numbersChallenge {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Numbers", value: numbersChallenge)
            }
            
            if let contextInfo = notification.contextInfo {
                Divider().padding(.leading, 100)
                NotificationInfoRow(label: "Context", value: contextInfo)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
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
            return .green
        } else if notification.isExpired && notification.pending {
            return .orange
        } else if notification.pending {
            return .blue
        } else {
            return .red
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

struct NotificationInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 12)
    }
}
