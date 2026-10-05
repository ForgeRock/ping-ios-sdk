//
//  TextOutputCallbackView.swift
//  PingExample
//
//  Copyright (c) 2025 - 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingJourney

struct TextOutputCallbackView: View {
    let callback: TextOutputCallback

    var body: some View {
        HStack(spacing: PingTheme.Spacing.small) {
            // Icon based on message type
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)

            // Message text
            Text(callback.message)
                .pingSectionHeader()
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iconName: String {
        switch callback.messageType {
        case .information:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
        default:
            return "gear.circle.fill"
        }
    }

    private var iconColor: Color {
        switch callback.messageType {
        case .information:
            return PingTheme.Color.statusInfo
        case .warning:
            return PingTheme.Color.statusWarning
        case .error:
            return PingTheme.Color.statusError
        default:
            return PingTheme.Color.contentSecondary
        }
    }
}
