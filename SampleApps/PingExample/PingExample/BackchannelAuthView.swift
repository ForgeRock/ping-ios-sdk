//
//  BackchannelAuthView.swift
//  PingExample
//
//  Copyright (c) 2026 Ping Identity Corporation. All rights reserved.
//
//  This software may be modified and distributed under the terms
//  of the MIT license. See the LICENSE file for details.
//

import Foundation
import SwiftUI
import PingOrchestrate
import PingJourney

/// Drives the AM/AIC backchannel authentication flow.
///
/// The user pastes the `redirectUri` that a federation gateway received from AM's
/// `/authenticate/backchannel/initialize` endpoint. The SDK's `Journey.start(backchannelUri:)`
/// extracts `authIndexType` / `authIndexValue` from the URI and drives the standard authenticate
/// journey — reusing the same callback rendering (`CallbackView`) and terminal-node handling as
/// `JourneyView`.
struct BackchannelAuthView: View {
    /// Reuses `JourneyViewModel` — the node/callback machinery is identical; only the entry point differs.
    @StateObject private var journeyViewModel = JourneyViewModel()
    /// A binding to the navigation stack path.
    @Binding var path: [MenuItem]

    var body: some View {
        ZStack {
            if journeyViewModel.showJourneyNameInput {
                // Show the redirect-URI input screen
                BackchannelUriInputView(journeyViewModel: journeyViewModel)
            } else {
                // Show the normal journey flow once the backchannel transaction has started
                ScrollView {
                    VStack {
                        Spacer()
                        // Handle different types of nodes in the Journey.
                        switch journeyViewModel.state.node {
                        case let continueNode as ContinueNode:
                            // Display the callback view for the next node.
                            CallbackView(journeyViewModel: journeyViewModel, node: continueNode)
                        case let errorNode as ErrorNode:
                            // Handle server-side errors (e.g., expired/invalid transaction)
                            ErrorNodeView(node: errorNode)
                            if let nextNode = errorNode.continueNode {
                                CallbackView(journeyViewModel: journeyViewModel, node: nextNode)
                            }
                        case let failureNode as FailureNode:
                            ErrorView(title: "Backchannel Failure", message: failureNode.cause.localizedDescription)
                        case is SuccessNode:
                            // Authentication successful, retrieve the session
                            VStack{}.onAppear {
                                path.removeLast()
                                path.append(.journeyToken)
                            }
                        default:
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

/// A view for pasting the gateway `redirectUri` before starting the backchannel flow.
struct BackchannelUriInputView: View {
    @ObservedObject var journeyViewModel: JourneyViewModel
    @State private var redirectUri: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("Logo")
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)

            VStack(spacing: 16) {
                Text("Backchannel Authentication")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Paste the redirect URI supplied by the federation gateway. The SDK reads authIndexType / authIndexValue from it and drives the authenticate journey.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Redirect URI", text: $redirectUri, axis: .vertical)
                    .lineLimit(2...5)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .font(.system(size: 14, design: .monospaced))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )

                if let error = journeyViewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                Spacer()

                NextButton(title: "Start Backchannel Auth") {
                    Task {
                        await journeyViewModel.startBackchannel(with: redirectUri)
                    }
                }
                .disabled(redirectUri.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Spacer()
        }
        .padding()
    }
}
