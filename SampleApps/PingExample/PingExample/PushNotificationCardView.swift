//
//  PushNotificationCardView.swift
//  PingExample
//
//  Copyright (c) 2025 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingPush

/// View to display a push notification card.
struct PushNotificationCardView: View {
    let notification: PushNotification
    @ObservedObject var viewModel: PushNotificationsViewModel

    var body: some View {
        Group {
            switch notification.pushType {
            case .default:
                DefaultNotificationView(notification: notification, viewModel: viewModel)
            case .biometric:
                BiometricNotificationView(notification: notification, viewModel: viewModel)
            case .challenge:
                ChallengeNotificationView(notification: notification, viewModel: viewModel)
            @unknown default:
                DefaultNotificationView(notification: notification, viewModel: viewModel)
            }
        }
    }
}
