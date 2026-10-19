//
//  MetadataView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import SwiftUI
import PingDavinci

/// Demo view for the DaVinci SDK Integrator connector's METADATA step.
/// Displays the opaque payload the flow sent and offers two buttons to
/// simulate a success or error result without invoking a real third-party
/// SDK.
struct MetadataView: View {
    let field: MetadataCollector
    let onNext: (Bool) -> Void

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
        VStack(alignment: .leading, spacing: PingTheme.Spacing.medium) {
            Text("SDK Metadata")
                .pingSectionHeader()

            Text("Payload from DaVinci:")
                .pingSupportingText()

            ScrollView {
                Text(prettyMetadata)
                    .font(PingTheme.Typography.monospacedCaption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PingTheme.Spacing.small)
                    .background(PingTheme.Color.groupedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: PingTheme.Shape.fieldRadius))
            }
            .frame(maxHeight: 240)

            HStack(spacing: PingTheme.Spacing.medium) {
                Button {
                    field.setResult(["verified": true, "score": 92])
                    onNext(true)
                } label: {
                    Text("Simulate success")
                }
                .buttonStyle(.pingAffirmative)

                Button {
                    field.setError(code: "USER_CANCELLED", message: "User cancelled the operation")
                    onNext(true)
                } label: {
                    Text("Simulate error")
                }
                .buttonStyle(.pingDestructive)
            }
        }
        .padding(.vertical, PingTheme.Spacing.small)
    }
}
