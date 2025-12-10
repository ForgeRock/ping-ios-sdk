//
//  ChallengeNotificationView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// A SwiftUI view representing a challenge authentication push notification
/// that allows the user to select a challenge number to approve the authentication.
struct ChallengeNotificationView: View {
    let notification: PushNotification
    @ObservedObject var viewModel: PushNotificationsViewModel

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Header with icon and timestamp
            HStack {
                Image(systemName: "number.circle.fill")
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
                    Text("Challenge Authentication")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(notification.createdAt, style: .relative)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if notification.isExpired {
                    Label("Expired", systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }

            // Message
            if let message = notification.messageText {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Challenge selection UI
            if !notification.isExpired {
                let challengeNumbers = notification.getNumbersChallenge()
                
                VStack(spacing: 24) {
                    Text("Select the number shown on your other device")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if !challengeNumbers.isEmpty {
                        HStack(spacing: 16) {
                            ForEach(challengeNumbers, id: \.self) { number in
                                ChallengeNumberButton(number: number) {
                                    Task {
                                        await viewModel.approveChallengeNotification(
                                            id: notification.id,
                                            challengeResponse: String(number)
                                        )
                                    }
                                }
                            }
                        }
                        
                        Spacer().frame(height: 8)
                        
                        Button(action: {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        }) {
                            Text("Cancel Authentication")
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    } else {
                        Text("No challenge numbers available")
                            .font(.system(size: 15))
                            .foregroundColor(.red)
                        
                        Spacer().frame(height: 16)
                        
                        Button(action: {
                            Task {
                                await viewModel.denyNotification(id: notification.id)
                            }
                        }) {
                            Text("Close")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                        }
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

/// A button displaying a challenge number as a circular button
struct ChallengeNumberButton: View {
    let number: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
    }
}
