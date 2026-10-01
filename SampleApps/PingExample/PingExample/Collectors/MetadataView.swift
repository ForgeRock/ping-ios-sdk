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
import PingOneMFA

/// Demo view for the DaVinci SDK Integrator connector's METADATA step.
/// Displays the opaque payload the flow sent.
///
/// When `metadata` is `{ "sdk": "MFA", "action": "MOBILE_PAYLOAD" }`, this view
/// automatically invokes `PingOneMFA.generateMobilePayload()` and continues the
/// flow. For any other payload it falls back to two buttons that simulate a
/// success or error result without invoking a real third-party SDK.
struct MetadataView: View {
    let field: MetadataCollector
    let onNext: (Bool) -> Void

    @State private var isCollectingMobilePayload = false

    private var isMobilePayloadRequest: Bool {
        (field.metadata["sdk"] as? String) == "MFA" &&
        (field.metadata["action"] as? String) == "MOBILE_PAYLOAD"
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
                HStack(spacing: 12) {
                    Button {
                        field.setResult(["verified": true, "score": 92])
                        onNext(true)
                    } label: {
                        Text("Simulate success")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themeButtonBackground)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button {
                        field.setError(code: "USER_CANCELLED", message: "User cancelled the operation")
                        onNext(true)
                    } label: {
                        Text("Simulate error")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.85))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }

    /// Lazily initializes PingOne MFA if needed, then generates the mobile
    /// payload and sets it as the collector's result under `mobilePayload` —
    /// which the SDK POSTs back as `formData["sdkMetadata"]["mobilePayload"]`.
    /// Falls back to `setError` on failure so the connector's error branch
    /// still receives a result, mirroring the "Simulate error" path above.
    private func collectMobilePayload() async {
        guard !isCollectingMobilePayload else { return }
        isCollectingMobilePayload = true

        do {
            if !ConfigurationManager.shared.isPingOneMFAInitialized {
                try await ConfigurationManager.shared.initializePingOneMFAClient()
            }
            let payload = try await PingOneMFA.generateMobilePayload()
            field.setResult(["mobilePayload": payload])
        } catch {
            field.setError(code: "MOBILE_PAYLOAD_FAILED", message: error.localizedDescription)
        }

        onNext(true)
    }
}
